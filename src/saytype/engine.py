"""Mic capture -> webrtcvad -> faster-whisper -> voice events. Always listening."""

import difflib
import queue
import threading
import numpy as np
import sounddevice as sd
import webrtcvad
from faster_whisper import WhisperModel
from collections import deque


SAMPLE_RATE = 16000
FRAME_DURATION_MS = 30
FRAME_SAMPLES = int(SAMPLE_RATE * FRAME_DURATION_MS / 1000)
SILENCE_REQUIRED = 0.3
MIN_SPEECH_DURATION = 0.15
MAX_UTTERANCE = 30.0

COMMANDS = {
    "send": "submit", "submit": "submit", "enter": "submit", "go": "submit",
    "sent": "submit", "sand": "submit", "cent": "submit",
    "go ahead": "submit", "confirm": "submit", "done": "submit",
    "cancel": "cancel", "stop": "cancel",
    "accept": "accept", "yes": "accept", "yeah": "accept", "approve": "accept",
    "reject": "reject", "no": "reject", "nope": "reject", "deny": "reject",
}


class VoiceEngine(threading.Thread):
    def __init__(self, event_queue: queue.Queue, model_size: str = "tiny.en"):
        super().__init__(daemon=True)
        self.event_queue = event_queue
        self.model_size = model_size
        self._stop_event = threading.Event()

    def run(self):
        print(f"[voice] Loading faster-whisper ({self.model_size})...", flush=True)
        model = WhisperModel(self.model_size, device="cpu", compute_type="int8")
        print("[voice] Model ready. Listening.", flush=True)

        vad = webrtcvad.Vad(3)

        audio_q: queue.Queue = queue.Queue()

        def audio_callback(indata, frames, time_info, status):
            audio_q.put(indata[:, 0].copy())

        ring = deque()
        audio_buffer = []
        silent_frames = 0
        speech_frames = 0
        in_speech = False

        silence_frames_needed = int(SILENCE_REQUIRED / (FRAME_DURATION_MS / 1000))
        min_speech_frames_needed = int(MIN_SPEECH_DURATION / (FRAME_DURATION_MS / 1000))
        max_frames = int(MAX_UTTERANCE / (FRAME_DURATION_MS / 1000))

        with sd.InputStream(
            samplerate=SAMPLE_RATE,
            channels=1,
            dtype="float32",
            blocksize=FRAME_SAMPLES,
            callback=audio_callback,
        ):
            while not self._stop_event.is_set():
                try:
                    chunk = audio_q.get(timeout=0.1)
                except queue.Empty:
                    continue

                ring.extend(chunk)

                while len(ring) >= FRAME_SAMPLES:
                    frame_float = np.array([ring.popleft() for _ in range(FRAME_SAMPLES)], dtype=np.float32)
                    frame_int16 = (frame_float * 32767).astype(np.int16)
                    frame_bytes = frame_int16.tobytes()

                    is_speech = vad.is_speech(frame_bytes, SAMPLE_RATE)

                    if is_speech:
                        if not in_speech:
                            in_speech = True
                            self.event_queue.put({"type": "hud_voice", "state": "listening"})
                            print("[voice] Speech detected", flush=True)
                        audio_buffer.append(frame_float)
                        speech_frames += 1
                        silent_frames = 0
                    elif in_speech:
                        audio_buffer.append(frame_float)
                        silent_frames += 1

                        if silent_frames >= silence_frames_needed:
                            if speech_frames >= min_speech_frames_needed:
                                audio = np.concatenate(audio_buffer)
                                self.event_queue.put({"type": "hud_voice", "state": "transcribing"})
                                self._transcribe(model, audio)
                            else:
                                print("[voice] Utterance too short", flush=True)
                            audio_buffer = []
                            speech_frames = 0
                            silent_frames = 0
                            in_speech = False
                            self.event_queue.put({"type": "hud_voice", "state": "idle"})

                    if in_speech and len(audio_buffer) >= max_frames:
                        audio = np.concatenate(audio_buffer)
                        self.event_queue.put({"type": "hud_voice", "state": "transcribing"})
                        self._transcribe(model, audio)
                        audio_buffer = []
                        speech_frames = 0
                        silent_frames = 0
                        in_speech = False
                        self.event_queue.put({"type": "hud_voice", "state": "idle"})

    def _transcribe(self, model: WhisperModel, audio: np.ndarray) -> None:
        print("[voice] Transcribing...", flush=True)
        segments, _ = model.transcribe(
            audio,
            language="en",
            beam_size=1,
            best_of=1,
            without_timestamps=True,
            condition_on_previous_text=False,
            vad_filter=True,
            vad_parameters={"min_silence_duration_ms": 300},
            hotwords="send submit enter go cancel accept reject",
        )
        text = " ".join(seg.text for seg in segments).strip()
        if not text:
            print("[voice] Empty transcription", flush=True)
            return

        print(f"[voice] Transcribed: {text!r}", flush=True)

        normalized = text.strip().lower().rstrip(".,!?")
        for prefix in ("okay ", "ok ", "please ", "now "):
            if normalized.startswith(prefix):
                normalized = normalized[len(prefix):]

        if normalized in COMMANDS:
            cmd = COMMANDS[normalized]
            print(f"[voice] Command: {cmd}", flush=True)
            self.event_queue.put({"type": "voice_command", "command": cmd})
        else:
            matches = difflib.get_close_matches(normalized, COMMANDS.keys(), n=1, cutoff=0.7)
            if matches:
                cmd = COMMANDS[matches[0]]
                print(f"[voice] Fuzzy command: {normalized!r} -> {cmd}", flush=True)
                self.event_queue.put({"type": "voice_command", "command": cmd})
            else:
                self.event_queue.put({"type": "voice_text", "text": text})

    def stop(self):
        self._stop_event.set()
