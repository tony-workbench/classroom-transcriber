# Classroom Transcriber

A local Mac app that transcribes English recordings with Whisper large-v3-turbo, aligns timestamps with WhisperX, and assigns speaker labels with pyannote Community-1. For each recording it saves a TXT transcript, SRT subtitles, and speaker-labeled Markdown in a `Transcribe` subfolder next to the recording. No paid API is used.

## What you need

- An Apple Silicon Mac. Development used a Mac with 24 GB RAM; long-recording requirements have not been measured.
- Python 3.12 and Xcode or Command Line Tools with `swiftc`.
- Internet access and free disk space for first-time package and model downloads.
- A Hugging Face account and read token; accept the [Community-1 model conditions](https://huggingface.co/pyannote/speaker-diarization-community-1) first.

## Install

1. Get the code:

   ```sh
   git clone https://github.com/tony-workbench/classroom-transcriber.git
   cd classroom-transcriber
   ```

2. Run `./setup.command` to create a separate Python environment, install the pinned packages and compile the app. The lock file records versions used on the development Mac; a clean installation has not yet been verified.

3. Create a read token at [Hugging Face token settings](https://huggingface.co/settings/tokens). For the first model download, use a short English recording:

   ```sh
   .venv/bin/python transcribe.py "/path/to/short-recording.m4a" --download --output-dir first-test
   ```

   Paste the token when prompted; it will not be displayed. Do not put it in a command or commit it. First-time setup requires a terminal. Daily use does not.

4. Open `课堂转写.app`, select an audio file or a folder containing one, and click “开始转写”. When it finishes, click “打开结果文件夹”. The app supports M4A, WAV, MP3, AAC and MP4.

Keep the app, virtual environment and model cache in the same project folder and location. A Finder alias can be placed on the desktop. Each run creates a separate output folder. Keep the Mac and app running until processing finishes; interrupted jobs must be started again.

## What has been checked

A synthetic short M4A passed the local transcription, alignment and diarization pipeline and produced all three formats. The same processing path saved files under the recording's `Transcribe` subfolder. The native app's graphical interaction, a clean installation, real classroom recordings and long recordings have not been tested.

Daily processing uses local models, enables Hugging Face offline mode and disables pyannote telemetry; first-time downloads require internet. A physical disconnect test has not been performed. Speaker labels are estimates, not names, and overlapping or distant speech may be misidentified. Audio, transcripts, credentials, virtual environments and model caches are not included in this repository.

The app and packaging were developed with Codex. Review transcripts before relying on them.
