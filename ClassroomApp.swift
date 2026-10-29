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

final class Controller: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    var fileLabel = NSTextField(wrappingLabelWithString: "请选择一段录音，或选择包含录音的文件夹。")
    var status = NSTextField(wrappingLabelWithString: "准备就绪")
    var selectButton = NSButton(title: "选择录音文件", target: nil, action: nil)
    var folderButton = NSButton(title: "选择录音文件夹", target: nil, action: nil)
    var start = NSButton(title: "开始转写和总结", target: nil, action: nil)
    var show = NSButton(title: "打开结果文件夹", target: nil, action: nil)
    var progress = NSProgressIndicator()
    var file: URL?
    var result: URL?
    var process: Process?
    let supported = ["m4a", "mp3", "wav", "aac", "mp4"]
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSRect(x: 0,y: 0,width: 660,height: 420), styleMask: [.titled,.closable,.miniaturizable], backing: .buffered, defer: false)
        window.title = "课堂录音转写"; window.center(); window.delegate = self
        let title = NSTextField(labelWithString: "课堂录音转写")
        title.font = .systemFont(ofSize: 25, weight: .semibold)
        let subtitle = NSTextField(wrappingLabelWithString: "选择英文录音，应用会转写并生成课堂总结，结果保存在录音所在文件夹的 Transcribe 子文件夹中。")
        subtitle.textColor = .secondaryLabelColor
        fileLabel.lineBreakMode = .byTruncatingMiddle
        status.textColor = .secondaryLabelColor
        selectButton.target=self; selectButton.action=#selector(chooseFile)
        folderButton.target=self; folderButton.action=#selector(chooseFolder)
        start.target=self; start.action=#selector(run); start.bezelStyle = .rounded; start.isEnabled=false
        show.target=self; show.action=#selector(showResult); show.isEnabled=false
        progress.style = .bar; progress.isIndeterminate=true; progress.isDisplayedWhenStopped=false
        let row = NSStackView(views:[selectButton,folderButton]); row.orientation = .horizontal; row.spacing=12
        let actions = NSStackView(views:[start,show]); actions.orientation = .horizontal; actions.spacing=12
        let stack = NSStackView(views:[title,subtitle,row,fileLabel,actions,progress,status]); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing=18; stack.translatesAutoresizingMaskIntoConstraints=false
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo:window.contentView!.leadingAnchor,constant:30),stack.trailingAnchor.constraint(equalTo:window.contentView!.trailingAnchor,constant:-30),stack.topAnchor.constraint(equalTo:window.contentView!.topAnchor,constant:28), progress.widthAnchor.constraint(equalToConstant:570)])
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true)
    }
    func select(_ url: URL) { file=url; fileLabel.stringValue="录音：\(url.path)"; start.isEnabled=true; status.stringValue="准备就绪。结果将保存在录音所在文件夹的 Transcribe 中。" }
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
            let task=Process(); task.executableURL=python; task.arguments=["-u",script.path,audio.path,dest.path]
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
                else if text.contains("Aligning words") { message="正在对齐文字和时间…" }
                else if text.contains("Detecting speakers") { message="正在区分说话人…" }
                else if text.contains("Starting local summary") || text.contains("Summarizing part") || text.contains("Combining notes") { message="正在本地生成课堂总结，长录音可能需要较长时间…" }
                else { message=nil }
                if let message=message { DispatchQueue.main.async { self?.status.stringValue=message } }
            }
            task.terminationHandler = { [weak self] p in DispatchQueue.main.async {
                guard let self=self else { return }
                self.process=nil; self.progress.stopAnimation(nil); self.selectButton.isEnabled=true; self.folderButton.isEnabled=true; self.start.isEnabled=true
                if p.terminationStatus == 0 {
                    self.status.stringValue="转写和课堂总结完成！点击“打开结果文件夹”查看。"; self.show.isEnabled=true
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

if CommandLine.arguments.count == 3 && CommandLine.arguments[1] == "--self-test" {
    let audio=URL(fileURLWithPath:CommandLine.arguments[2]); let dest=try outputDirectory(audio)
    let p=Process(); p.executableURL=python; p.arguments=["-u",script.path,audio.path,dest.path]; try p.run(); p.waitUntilExit(); print("RESULT_DIR=\(dest.path)"); exit(p.terminationStatus)
}
let app=NSApplication.shared; let delegate=Controller(); app.delegate=delegate; app.setActivationPolicy(.regular); app.run()
