import Foundation

let DIALOG = "/usr/local/bin/dialog"
let DIALOG_COMMAND_FILE = "/var/tmp/dialog.log"
let FILE_LOCATION = FileManager.default.currentDirectoryPath
let IMG_LOCATION = "\(FILE_LOCATION)/imgs"

class DialogAlert {
    var contentDict: [String: Any] = [
        // Buttons Options
        "button1text": "Continue",
        "button2text": "Back",
        // Window Options
        "height": "500",
        "width": "900",
        // Icon Options
        "icon": "\(IMG_LOCATION)/2023 MacAdmins Logo-Circle-Black.png",
        "iconsize": "300",
        // Content
        "title": "none",
        "message": "none",
        "messagefont": "size=16"
    ]

    func alert(_ contentDict: [String: Any], background: Bool = false) -> [String: Any] {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: contentDict)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                return [:]
            }
            let arguments = [DIALOG, "-o", "-p", "--jsonstring", jsonString, "--json"]
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = arguments
            let pipe = Pipe()
            process.standardOutput = pipe
            try process.run()

            if background {
                return ["process": process]
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)
            let success = process.terminationStatus == 0
            let resultDict: [String: Any] = [
                "stdout": output ?? "",
                "stderr": "",
                "status": process.terminationStatus,
                "success": success
            ]
            return resultDict
        } catch {
            return [:]
        }
    }

    func updateDialog(_ command: String, value: String = "") {
        let dialogCommand = "\(command): \(value)\n"
        if let dialogData = dialogCommand.data(using: .utf8),
            let fileHandle = FileHandle(forWritingAtPath: DIALOG_COMMAND_FILE) {
            fileHandle.seekToEndOfFile()
            fileHandle.write(dialogData)
            fileHandle.closeFile()
        }
    }
}

func main() {
    let newAlert = DialogAlert()
    newAlert.contentDict["title"] = "Hello World"
    newAlert.contentDict["message"] = "This is a Swift Example"
    let status = newAlert.alert(newAlert.contentDict)
    print(status)
}

main()