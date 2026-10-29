# Classroom Transcriber

A local Mac app for English lecture recordings. It uses Whisper large-v3-turbo through MLX on Apple Silicon, and can generate an English summary with Qwen3-8B. An optional full mode adds WhisperX word alignment and pyannote Community-1 speaker labels. Processing runs locally and does not use a paid API.

## What you need

- An Apple Silicon Mac. Development used an M5 Mac with 10 GPU cores, 24 GB RAM and macOS 27.2; other hardware and long-recording memory requirements have not been measured.
- Python 3.12 and Xcode or Command Line Tools with `swiftc`.
- Internet access and free disk space for first-time setup. The Whisper model is about 1.6 GB and the summary model about 4.6 GB; Python environments and optional full-mode models require additional space.
- For full mode only, a Hugging Face account and read token. Accept the [Community-1 model conditions](https://huggingface.co/pyannote/speaker-diarization-community-1) first.

## Install

1. Get the code:

   ```sh
   git clone https://github.com/tony-workbench/classroom-transcriber.git
   cd classroom-transcriber
   ```

2. Run `./setup.command` to create three separate Python environments, install the recorded package versions and compile the app. The lock files record versions used on the development Mac; a clean installation has not yet been verified.

3. Download the Whisper model for all modes:

   ```sh
   HF_HOME="$PWD/cache/whisper-mlx-hf" .whisper-mlx-venv/bin/hf download mlx-community/whisper-large-v3-turbo --revision a4aaeec0636e6fef84abdcbe3544cb2bf7e9f6fb --local-dir "$PWD/cache/whisper-mlx"
   ```

4. For either mode with a summary, download the Qwen model:

   ```sh
   HF_HOME="$PWD/cache/summary-hf" .summary-venv/bin/hf download mlx-community/Qwen3-8B-4bit --revision 545dc4251c05440727734bcd94334791f6ab0192 --local-dir "$PWD/cache/summary-model"
   ```

5. For full mode, accept the Community-1 conditions and create a read token at [Hugging Face token settings](https://huggingface.co/settings/tokens). Then run:

   ```sh
   .venv/bin/python prepare_full.py
   ```

   Paste the token at the prompt; it will not be displayed or saved by this script. This step downloads Community-1 and the English alignment model. Do not place the token in a command or commit it. The setup path has not been tested on a clean machine.

6. Open `课堂转写.app`. Drag a recording onto the window or select a file or folder. After choosing a recording, select one of the three options:

   - **只转写** — transcribe only.
   - **转写＋总结** — transcribe and produce an English summary.
   - **完整处理** — transcribe, align words, label speakers and summarize.

   Processing starts after the choice. Daily use does not require a terminal. Supported input types are M4A, WAV, MP3, AAC and MP4.

Results are stored in a new `Transcribe` subfolder next to the recording. Each run gets its own folder; existing results are not overwritten. TXT, Markdown and SRT are produced in every mode. In the first two modes timestamps are approximate speech-region boundaries, not precise subtitle alignment, and no speaker labels are provided. Full mode adds word alignment and estimated speaker labels. If summarization fails, completed transcript files remain available.

Keep the app, all three virtual environments and model caches together in the same project folder and location. A Finder alias can be placed on the desktop. Keep the Mac and app running until processing finishes; interrupted jobs must be started again.

## What has been checked

On the development Mac, all three processing paths passed short synthetic audio tests. The installed app's self-test also passed a short transcription-only case. Native drag-and-drop and dialog interaction have not yet been manually verified. A real one-hour recording was transcribed on the GPU, and its transcript was summarized separately; this was not a complete timed run of the final app. A short two-voice synthetic recording received two distinct speaker labels in full mode. A prior short end-to-end test ran with networking denied to the test process; the entire Mac was not disconnected.

On the one-hour recording, a two-section summary test took about 1 minute 49 seconds. An earlier five-section summary took about 8 minutes 58 seconds while other GPU tests overlapped, so the timings are not a controlled comparison. The shorter result omitted detailed timestamps and some details; summaries can add or misinterpret information and should be checked against the recording.

Additional transcription acceleration experiments and their limitations are in [docs/transcription-speed-experiments.md](docs/transcription-speed-experiments.md). They are not enabled in the app.

Daily processing uses local models and enables Hugging Face offline mode. Long transcripts are summarized in sections and combined. Speech detection, transcripts and speaker labels are estimates, and audio and outputs remain on the machine. Recordings, transcripts, credentials, virtual environments and model caches are not included in this repository.

The app and packaging were developed with Codex.
