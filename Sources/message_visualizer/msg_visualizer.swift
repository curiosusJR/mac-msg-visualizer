import Cocoa
import Carbon.HIToolbox.Events
import SwiftCLI

enum Size: String, ConvertibleFromString, CaseIterable {
    case small
    case normal
    case large
}

struct WindowSize {
    let fontSize: CGFloat
    let paddingVertical: CGFloat
    let paddingHorizontal: CGFloat
}

struct Bounds: Decodable {
    let bounds: CGRect
}

extension WindowSize {
    init(size: Size) {
        switch size {
            case .small:
                self.init(fontSize: 18.0, paddingVertical: 10.0, paddingHorizontal: 12.0)
            case .large:
                self.init(fontSize: 26.0, paddingVertical: 16.0, paddingHorizontal: 20.0)
            default:
                self.init(fontSize: 22.0, paddingVertical: 14.0, paddingHorizontal: 18.0)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let window: NSWindow = {
        let window = NSWindow(
            contentRect: CGRect(x: 200, y: 200, width: 400, height: 200),
            styleMask: [.titled],
            backing: .buffered,
            defer: true
        )
        
        window.titleVisibility = .hidden
        window.styleMask.remove(.titled)
        window.backgroundColor = .clear
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        
        return window
    }()
    
    let field: NSTextView = {
        let textView = NSTextView()
        textView.backgroundColor = .clear
        textView.isSelectable = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        return textView
    }()
    
    let windowSize: WindowSize
    let keyCombinationsOnly: Bool
    let delay: Double
    let display: Int?
    var bounds: CGRect?
    let text: String
    
    weak var timer: Timer?
    var eventTap: CFMachPort?
    
    init(
        size: Size?,
        keyCombinationsOnly: Bool,
        delay: Double?,
        display: Int?,
        bounds: String?,
        text: String
    ) {
        self.windowSize = WindowSize(size: size ?? .normal)
        self.keyCombinationsOnly = keyCombinationsOnly
        self.delay = delay ?? 1.5
        self.display = display
        self.bounds = nil
        self.text = text
        
        if let cropBounds = bounds {
            do {
                let decoded: Bounds = try cropBounds.jsonDecoded()
                self.bounds = decoded.bounds
            } catch {
                print("here \(error)");
                self.bounds = nil
            }
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let visualEffect = NSVisualEffectView()
        visualEffect.translatesAutoresizingMaskIntoConstraints = false
        visualEffect.material = .appearanceBased
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 10.0
        
        guard let contentView = window.contentView else {
            fatalError()
        }
        
        contentView.addSubview(visualEffect)
        contentView.addSubview(field)
        
        visualEffect.leadingAnchor.constraint(equalTo: contentView.leadingAnchor).isActive = true
        visualEffect.trailingAnchor.constraint(equalTo: contentView.trailingAnchor).isActive = true
        visualEffect.topAnchor.constraint(equalTo: contentView.topAnchor).isActive = true
        visualEffect.bottomAnchor.constraint(equalTo: contentView.bottomAnchor).isActive = true
        
        field.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: windowSize.paddingHorizontal).isActive = true
        field.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -windowSize.paddingHorizontal).isActive = true
        field.topAnchor.constraint(equalTo: contentView.topAnchor, constant: windowSize.paddingVertical).isActive = true
        field.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: windowSize.paddingVertical).isActive = true
        
       // DispatchQueue.main.async {
        updateText(text)
       // }
        
        guard let screen = (display == nil ? nil : NSScreen.screens.first { screen in
            (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? Int) == display
        }) ?? window.screen else {
            return
        }
        
        let windowFrameSize = window.frame.size
        let screenFrame = screen.frame
        //print( windowFrameSize)
        //print(screenFrame)
        if let cropBounds = bounds {
            let x = screenFrame.origin.x + cropBounds.origin.x + (cropBounds.width / 2) - (windowFrameSize.width / 2)
            let y = screenFrame.origin.x + cropBounds.origin.y + (cropBounds.height * 0.15) - (windowFrameSize.height / 2)
            //print(x,y)
            window.setFrame(NSMakeRect(x, y, windowFrameSize.width, windowFrameSize.height), display: true)
        } else {
            let x = (screenFrame.origin.x + (screenFrame.width ) - (windowFrameSize.width))*0.988
            let y = (screenFrame.origin.y + (screenFrame.height ) - (windowFrameSize.height))*0.968
            //print(x,y)
            //print(screenFrame.origin.x, screenFrame.width, windowFrameSize.width)
            //print(screenFrame.origin.y, screenFrame.height, windowFrameSize.height)
            window.setFrame(NSMakeRect(x, y, windowFrameSize.width, windowFrameSize.height), display: true)
        }
        
    }
    
    func updateText(_ untrimmed: String, onlyMeta: Bool = false) {
        let string = untrimmed.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if string.count == 0 {
            if timer == nil {
                window.orderOut(self)
            }
            return
        } else if onlyMeta {
            timer?.invalidate()
            timer = nil
        } else {
            queueClear()
        }
        
        let windowFrame = window.frame
        
        var originalFrame = field.frame
        originalFrame.size.width = 500 // Max width of the view
        field.frame = originalFrame
        field.textStorage?.setAttributedString(NSAttributedString(string: string))
        field.textColor = .textColor
        field.alignment = .center
        
        if #available(macOS 10.15, *) {
            field.font = NSFont.monospacedSystemFont(ofSize: windowSize.fontSize, weight: .bold)
        } else {
            field.font = NSFont.systemFont(ofSize: windowSize.fontSize, weight: .bold)
        }
        
        guard
            let layoutManager = field.layoutManager,
            let textContainer = field.textContainer
        else {
            return
        }
        
        layoutManager.ensureLayout(for: textContainer)
        let computedSize = layoutManager.usedRect(for: textContainer).size
        field.frame.size = computedSize
        
        // Padding for constraints
        let windowFrameSize = CGSize(width: computedSize.width + (2 * windowSize.paddingHorizontal), height: computedSize.height + (2 * windowSize.paddingVertical))
        
        let x = windowFrame.midX - (windowFrameSize.width / 2)
        let y = windowFrame.midY - (windowFrameSize.height / 2)
        //let x = 0.0
        //let y = 0.0
        let frame = CGRect(x: x, y: y, width: windowFrameSize.width, height: windowFrameSize.height)
        
        window.setFrame(frame, display: true)
        //window.setFrameOrigin(NSPoint(x: x, y: y))
        //window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
    
    
    
    func queueClear() {
        timer?.invalidate()
        
        timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.timer?.invalidate()
            self?.timer = nil
            self?.updateText("")
            NSApplication.shared.terminate(nil)
        }
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
           // 这里可以执行一些终止前的清理工作，如保存数据
           // 返回 .terminateNow 表示立即终止程序
           return .terminateNow
       }
}
