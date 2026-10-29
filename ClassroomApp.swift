import Cocoa
import UniformTypeIdentifiers

let fm = FileManager.default
let root = Bundle.main.bundleURL.resolvingSymlinksInPath().deletingLastPathComponent()
let python = root.appendingPathComponent(".venv/bin/python")
let script = root.appendingPathComponent("pipeline.py")

func outputDirectory(_ file: URL) throws -> URL {
    let base = file.deletingLastPathComponent().appendingPathComponent("Transcribe", isDirectory: true)
    try fm.createDirectory(at: base, withIntermediateDirectories: true)
    let suffix = String(UUID().uuidString.prefix(8))
    let dest = base.appendingPathComponent(file.deletingPathExtension().lastPathComponent + "-" + suffix, isDirectory: true)
    try fm.createDirectory(at: dest, withIntermediateDirectories: false)
    return dest
}

final class AudioDropView: NSView {
    var onFile: ((URL) -> Void)?
    override init(frame: NSRect) { super.init(frame: frame); registerForDraggedTypes([.fileURL]); wantsLayer = true; layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor; layer?.cornerRadius = 8; layer?.borderWidth = 1; layer?.borderColor = NSColor.separatorColor.cgColor }
    required init?(coder: NSCoder) { fatalError("Not implemented") }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let urls = sender.draggingPasteboard.readObjects(forClasses:[NSURL.self], options:[.urlReadingFileURLsOnly:true]) as? [URL], urls.count == 1, ["m4a","mp3","wav","aac","mp4"].contains(urls[0].pathExtension.lowercased()) else { return [] }
        return .copy
    }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard.readObjects(forClasses:[NSURL.self], options:[.urlReadingFileURLsOnly:true]) as? [URL], urls.count == 1, ["m4a","mp3","wav","aac","mp4"].contains(urls[0].pathExtension.lowercased()) else { return false }
        onFile?(urls[0]); return true
    }
}

final class Controller: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    var fileLabel = NSTextField(wrappingLabelWithString: "请选择一段录音，或选择包含录音的文件夹。")
    var status = NSTextField(wrappingLabelWithString: "准备就绪")
    var selectButton = NSButton(title: "选择录音文件", target: nil, action: nil)
    var folderButton = NSButton(title: "选择录音文件夹", target: nil, action: nil)
    var start = NSButton(title: "开始转写和总结", target: nil, action: nil)
    var show = NSButton(title: "打开结果文件夹", target: nil, action: nil)
    var selectedMode = "--summary"
    var dropView = AudioDropView(frame: NSRect(x:0,y:0,width:570,height:52))
    var progress = NSProgressIndicator()
    var file: URL?
    var result: URL?
    var process: Process?
    let supported = ["m4a", "mp3", "wav", "aac", "mp4"]
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSRect(x: 0,y: 0,width: 660,height: 480), styleMask: [.titled,.closable,.miniaturizable], backing: .buffered, defer: false)
        window.title = "课堂录音转写"; window.center(); window.delegate = self
        let title = NSTextField(labelWithString: "课堂录音转写")
        title.font = .systemFont(ofSize: 25, weight: .semibold)
        let subtitle = NSTextField(wrappingLabelWithString: "选择英文录音，然后选择处理方式；结果保存在录音所在文件夹的 Transcribe 子文件夹中。")
        subtitle.textColor = .secondaryLabelColor
        fileLabel.lineBreakMode = .byTruncatingMiddle
        status.textColor = .secondaryLabelColor
        selectButton.target=self; selectButton.action=#selector(chooseFile)
        folderButton.target=self; folderButton.action=#selector(chooseFolder)
        start.target=self; start.action=#selector(run); start.bezelStyle = .rounded; start.isEnabled=false
        show.target=self; show.action=#selector(showResult); show.isEnabled=false
        progress.style = .bar; progress.isIndeterminate=true; progress.isDisplayedWhenStopped=false
        dropView.onFile = { [weak self] url in guard self?.process == nil else { return }; self?.select(url) }
        let dropLabel=NSTextField(labelWithString:"把录音拖到这里")
        dropLabel.textColor = .secondaryLabelColor; dropLabel.alignment = .center; dropLabel.translatesAutoresizingMaskIntoConstraints=false
        dropView.addSubview(dropLabel)
        NSLayoutConstraint.activate([dropLabel.centerXAnchor.constraint(equalTo:dropView.centerXAnchor),dropLabel.centerYAnchor.constraint(equalTo:dropView.centerYAnchor),dropView.widthAnchor.constraint(equalToConstant:570),dropView.heightAnchor.constraint(equalToConstant:52)])
        let row = NSStackView(views:[selectButton,folderButton]); row.orientation = .horizontal; row.spacing=12
        let actions = NSStackView(views:[show]); actions.orientation = .horizontal; actions.spacing=12
        let stack = NSStackView(views:[title,subtitle,dropView,row,fileLabel,actions,progress,status]); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing=18; stack.translatesAutoresizingMaskIntoConstraints=false
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo:window.contentView!.leadingAnchor,constant:30),stack.trailingAnchor.constraint(equalTo:window.contentView!.trailingAnchor,constant:-30),stack.topAnchor.constraint(equalTo:window.contentView!.topAnchor,constant:28), progress.widthAnchor.constraint(equalToConstant:570)])
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true)
    }
    func select(_ url: URL) {
        let choice=NSAlert(); choice.messageText="选择处理方式"; choice.informativeText="录音：\(url.lastPathComponent)\n\n只转写最快；完整处理会增加时间对齐与说话人区分。"
        choice.addButton(withTitle:"只转写"); choice.addButton(withTitle:"转写＋总结"); choice.addButton(withTitle:"完整处理"); choice.addButton(withTitle:"取消")
        switch choice.runModal() {
        case .alertFirstButtonReturn: selectedMode="--transcribe-only"
        case .alertSecondButtonReturn: selectedMode="--summary"
        case .alertThirdButtonReturn: selectedMode="--full"
        default: return
        }
        file=url; fileLabel.stringValue="录音：\(url.path)"; run()
    }
    @objc func chooseFile() {
        let panel=NSOpenPanel(); panel.title="选择英文录音"; panel.canChooseDirectories=false; panel.canChooseFiles=true; panel.allowsMultipleSelection=false
        panel.allowedContentTypes=supported.compactMap { UTType(filenameExtension:$0) }
        if panel.runModal() == .OK, let url=panel.url { select(url) }
    }
    @objc func chooseFolder() {
        let panel=NSOpenPanel(); panel.title="选择包含录音的文件夹"; panel.canChooseDirectories=true; panel.canChooseFiles=false
        guard panel.runModal() == .OK, let folder=panel.url else { return }
        let urls=(try? fm.contentsOfDirectory(at:folder, includingPropertiesForKeys:[.isRegularFileKey], options:[.skipsHiddenFiles])) ?? []
        let candidates=urls.filter { supported.contains($0.pathExtension.lowercased()) && ((try? $0.resourceValues(forKeys:[.isRegularFileKey]).isRegularFile) == true) }.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        if candidates.isEmpty { let a=NSAlert(); a.messageText="这个文件夹里没有支持的录音"; a.informativeText="请放入 M4A、WAV、MP3、AAC 或 MP4 文件后重试。"; a.runModal(); return }
        let alert=NSAlert(); alert.messageText="选择要转写的录音"; alert.informativeText="结果将保存在该文件夹的 Transcribe 子文件夹中。"; alert.addButton(withTitle:"选择"); alert.addButton(withTitle:"取消")
        let popup=NSPopUpButton(frame:NSRect(x:0,y:0,width:440,height:26)); popup.addItems(withTitles:candidates.map{$0.lastPathComponent}); alert.accessoryView=popup
        if alert.runModal() == .alertFirstButtonReturn { select(candidates[popup.indexOfSelectedItem]) }
    }
    @objc func run() {
        guard let audio=file else { return }
        do {
            let dest=try outputDirectory(audio); result=dest
            let mode = selectedMode
            let includeSummary = mode != "--transcribe-only"
            let task=Process(); task.executableURL=python; task.arguments=["-u",script.path,audio.path,dest.path,mode]
            let pipe=Pipe(); task.standardOutput=pipe; task.standardError=pipe
            let logURL=dest.appendingPathComponent("处理日志.txt")
            fm.createFile(atPath:logURL.path, contents:nil)
            let log=try FileHandle(forWritingTo:logURL)
            pipe.fileHandleForReading.readabilityHandler = { [weak self] h in
                let data=h.availableData; if data.isEmpty { h.readabilityHandler=nil; return }
                try? log.write(contentsOf:data)
                let text=String(decoding:data,as:UTF8.self)
                let message: String?
                if text.contains("Transcribing on CPU") { message="正在转写英文录音。长录音可能需要较长时间…" }
                else if text.contains("Detecting speech") { message="正在检测语音片段…" }
                else if let range = text.range(of: #"GPU transcription: (\d+)/(\d+)"#, options: .regularExpression) {
                    let counts = text[range].replacingOccurrences(of: "GPU transcription: ", with: "")
                    message = "正在用 GPU 转写语音片段：\(counts)"
                }
                else if text.contains("Transcribing speech using Apple GPU") { message="正在用 Apple GPU 转写录音…" }
                else if text.contains("Aligning words") { message="正在对齐文字与时间…" }
                else if text.contains("Detecting speakers") { message="正在区分说话人…" }
                else if let range = text.range(of: #"Summarizing part (\d+)/(\d+)"#, options: .regularExpression) {
                    let counts = text[range].replacingOccurrences(of: "Summarizing part ", with: "")
                    message = "正在总结片段：\(counts)"
                }
                else if text.contains("Combining notes") { message="正在合并课堂总结…" }
                else if text.contains("Starting local summary") { message="正在准备课堂总结…" }
                else { message=nil }
                if let message=message { DispatchQueue.main.async { self?.status.stringValue=message } }
            }
            task.terminationHandler = { [weak self] p in DispatchQueue.main.async {
                guard let self=self else { return }
                self.process=nil; self.progress.stopAnimation(nil); self.selectButton.isEnabled=true; self.folderButton.isEnabled=true; self.start.isEnabled=true
                if p.terminationStatus == 0 {
                    self.status.stringValue = includeSummary ? "转写和课堂总结完成！点击“打开结果文件夹”查看。" : "转写完成！点击“打开结果文件夹”查看。"; self.show.isEnabled=true
                } else if p.terminationStatus == 2 { self.status.stringValue="转写已完成，但总结失败。原始转写已保留，请打开结果文件夹查看日志。"; self.show.isEnabled=true } else { self.status.stringValue="转写失败（代码 \(p.terminationStatus)）。请打开结果文件夹查看日志。"; self.show.isEnabled=true }
            }}
            try task.run(); process=task; selectButton.isEnabled=false; folderButton.isEnabled=false; start.isEnabled=false; show.isEnabled=false; progress.startAnimation(nil); status.stringValue="正在读取录音…"
        } catch { status.stringValue="无法开始：\(error.localizedDescription)" }
    }
    @objc func showResult() { if let result=result { NSWorkspace.shared.open(result) } }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if process != nil { let a=NSAlert(); a.messageText="转写还在进行"; a.informativeText="请等转写完成后再关闭应用。"; a.addButton(withTitle:"继续等待"); a.runModal(); return false }
        return true
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if process != nil { let a=NSAlert(); a.messageText="转写还在进行"; a.informativeText="请等待转写完成再退出。"; a.addButton(withTitle:"继续等待"); a.runModal(); return .terminateCancel }
        return .terminateNow
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool { true }
}

if CommandLine.arguments.count >= 3 && CommandLine.arguments[1] == "--self-test" {
    let audio=URL(fileURLWithPath:CommandLine.arguments[2]); let dest=try outputDirectory(audio)
    let p=Process(); p.executableURL=python; p.arguments=["-u",script.path,audio.path,dest.path] + Array(CommandLine.arguments.dropFirst(3)); try p.run(); p.waitUntilExit(); print("RESULT_DIR=\(dest.path)"); exit(p.terminationStatus)
}
let app=NSApplication.shared; let delegate=Controller(); app.delegate=delegate; app.setActivationPolicy(.regular); app.run()
