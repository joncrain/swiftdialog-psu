import json
import os
import subprocess

DIALOG = "/usr/local/bin/dialog"
DIALOG_COMMAND_FILE = "/var/tmp/dialog.log"
FILE_LOCATION = os.path.dirname(os.path.realpath(__file__))
IMG_LOCATION = os.path.join(FILE_LOCATION, "imgs")


class DialogAlert:
    def __init__(self):
        # set the default look of the alert
        self.content_dict = {
            # Buttons Options
            "button1text": "Continue",
            "button2text": "Back",
            # Window Options
            "height": "500",
            "width": "900",
            # Icon Options
            "icon": os.path.join(IMG_LOCATION, "2023 MacAdmins Logo-Circle-White.png"),
            "iconsize": "300",
            # Content
            "title": "none",
            "message": "none",
            "messagefont": "size=16",
        }

    def alert(self, contentDict, background=False):
        """Runs the SwiftDialog app and returns the exit code"""
        jsonString = json.dumps(contentDict)
        cmd = [DIALOG, "-o", "-p", "--jsonstring", jsonString, "--json"]
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE)
        if background:
            return proc
        (out, err) = proc.communicate()
        result_dict = {
            "stdout": out,
            "stderr": err,
            "status": proc.returncode,
            "success": True if proc.returncode == 0 else False,
        }
        return result_dict

    def update_dialog(self, command, value=""):
        """Updates the current dialog window"""
        with open(DIALOG_COMMAND_FILE, "a") as dialog_file:
            dialog_file.write(f"{command}: {value}\n")


def main():
    new_alert = DialogAlert()
    new_alert.content_dict["title"] = "Hello World"
    new_alert.content_dict["message"] = "This is a Python Example"
    status = new_alert.alert(new_alert.content_dict)
    print(status)


if __name__ == "__main__":
    main()
