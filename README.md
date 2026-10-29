# Classroom Transcriber

A local Mac app that transcribes English recordings with Whisper large-v3-turbo, aligns timestamps with WhisperX, separates speakers with pyannote Community-1, and produces English lecture summaries with Qwen3-8B and MLX-LM. It saves TXT, SRT, speaker-labeled Markdown and summary Markdown in a `Transcribe` subfolder next to the recording. No paid API is used.

## What you need

- An Apple Silicon Mac. Development used macOS 27.2 and 24 GB RAM; long-recording requirements have not been measured.
- Python 3.12 and Xcode or Command Line Tools with `swiftc`.
- Internet access and sufficient free disk space for first-time package and model downloads. The summary model is about 4.6 GB; other models and environments also require space.
- A Hugging Face account and read token; accept the [Community-1 model conditions](https://huggingface.co/pyannote/speaker-diarization-community-1) first.

## Install

1. Get the code:

   ```sh
   git clone https://github.com/tony-workbench/classroom-transcriber.git
   cd classroom-transcriber
   ```

2. Run `./setup.command` to create two separate Python environments, install the pinned packages and compile the app. These lock files record versions used on the development Mac; a clean installation has not yet been verified.

3. Download the summary model into this project:

   ```sh
   HF_HOME="$PWD/cache/summary-hf" .summary-venv/bin/hf download mlx-community/Qwen3-8B-4bit --revision 545dc4251c05440727734bcd94334791f6ab0192 --local-dir "$PWD/cache/summary-model"
   ```

4. Create a read token at [Hugging Face token settings](https://huggingface.co/settings/tokens). For the first transcription model download, use a short English recording:

   ```sh
   .venv/bin/python transcribe.py "/path/to/short-recording.m4a" --download --output-dir first-test
   ```

   Paste the token when prompted; it will not be displayed. Do not put it in a command or commit it. First-time setup requires a terminal. Daily use does not.

5. Open `课堂转写.app`, select an audio file or a folder containing one, and click “开始转写和总结”. When it finishes, click “打开结果文件夹”. The app supports M4A, WAV, MP3, AAC and MP4.

Keep the app, both virtual environments and model caches in the same project folder and location. A Finder alias can be placed on the desktop. Each run creates a separate output folder. Keep the Mac and app running until processing finishes; interrupted jobs must be started again. If summarization fails, the transcript files remain available.

## What has been checked

On the development Mac, short synthetic M4A recordings passed the installed app's self-test path and produced all four outputs. A synthetic two-voice dialogue received two distinct speaker labels, with the first label reused when that voice returned. With networking denied to the test process, the same short end-to-end path completed; the entire Mac was not disconnected. A separate failure test confirmed transcripts remain if the summary model is unavailable. The GUI interactions, clean installation, real classroom audio, long recordings and speaker accuracy in noisy or overlapping speech have not been tested.

Daily processing uses local models, enables Hugging Face offline mode and disables pyannote telemetry. Long transcripts are summarized in sections and combined. Summaries and speaker labels can omit or misinterpret details; check them against the recording. Audio, transcripts, credentials, virtual environments and model caches are not included in this repository.

The app and packaging were developed with Codex.
