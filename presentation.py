import glob
import json
import logging
import os
import subprocess
import sys
import time

DIALOG = "/usr/local/bin/dialog"
DIALOG_COMMAND_FILE = "/var/tmp/dialog.log"
SCRIPT_PATH = os.path.abspath(__file__)
FILE_LOCATION = os.path.dirname(SCRIPT_PATH)
IMG_LOCATION = os.path.join(FILE_LOCATION, "imgs")


class DialogAlert:
    def __init__(self):
        # set the default look of the alert
        self.content_dict = {
            # Buttons
            "button1text": "Continue",
            "button2text": "Back",
            # Window
            "height": "500",
            "width": "900",
            # Icon
            "icon": f"{IMG_LOCATION}/2023 MacAdmins Logo-Circle-Black.png",
            "iconsize": "500",
            # Message Content
            "message": "Uh oh! Something went wrong.",
            "messagefont": "size=16",
            "title": "none",
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


### Utils ###


def run_subp(command, input=None):
    """
    Run a subprocess.
    Command must be an array of strings, allows optional input.
    Returns results in a dictionary.
    """
    # Validate that command is not a string
    if isinstance(command, str):
        # Not an array!
        logging.info("TypeError in cmd")
        raise TypeError("Command must be an array")

    proc = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    (out, err) = proc.communicate(input)
    result_dict = {
        "stdout": out,
        "stderr": err,
        "status": proc.returncode,
        "success": True if proc.returncode == 0 else False,
    }
    # logging.info(f"Command: {command}")
    # logging.info(f"Result: {result_dict}")
    return result_dict


def toggle_dark_mode(status):
    cmd = [
        "osascript",
        "-e",
        f'tell application "System Events" to tell appearance preferences to set dark mode to {status}',
    ]
    run_subp(cmd)


def setup_logging():
    log_file = f"{FILE_LOCATION}Logs/dialog.log"
    directory = os.path.dirname(log_file)
    if not os.path.exists(directory):
        os.makedirs(directory)
    logger = logging.getLogger(__name__)
    logging.basicConfig(
        level=logging.DEBUG,
        format="%(levelname)-8s: %(asctime)s %(module)-20s: %(message)s",
        datefmt="%Y/%m/%d %H:%M:%S",
        filename=log_file,
        filemode="w",
    )
    console = logging.StreamHandler()
    console.setLevel(logging.INFO)
    formatter = logging.Formatter("%(levelname)-8s %(module)-20s:  %(message)s")
    console.setFormatter(formatter)
    logging.getLogger("").addHandler(console)


### Steps ###


def run_slide(file_name):
    slide = DialogAlert()
    # open json file and add to content_dict
    with open(file_name, "r") as f:
        slide.content_dict.update(json.load(f))

    logging.info(f"Alert for {file_name}")
    title = slide.content_dict["title"]
    if "01-why0.json" in file_name:
        message_steps = [
            "# CocoaDialog",
            "# Nudge",
            "# jamfHelper",
            "# umad",
            "# Yo",
            "# DEP Notify",
            "# IBM Notifier",
            "# GrowlNotify",
            "# terminal-notifier",
            "# Nibbler",
            "# Why swiftDialog?",
        ]

        alert = slide.alert(slide.content_dict, background=True)
        logging.info("Run why updates")

        for message in message_steps:
            time.sleep(5)
            slide.update_dialog("message", message)

        slide.update_dialog("button1", "enable")
        slide.update_dialog("button2", "enable")

        out, err = alert.communicate()
        alert = {
            "stdout": out,
            "stderr": err,
            "status": alert.returncode,
            "success": alert.returncode == 0,
        }
    else:
        alert = slide.alert(slide.content_dict)

    titles = [
        "example-bash-chaining-commands.sh",
        "example-bash-send-commands.sh",
        "example-python.py",
        "example-golang.go",
        "example-swift.swift",
        "setup_your_mac.sh",
        "mdm_check.sh",
    ]

    if title in titles:
        file_extension = title.split(".")[-1]
        logging.info("Running demo")
        if file_extension == "sh":
            cmd = [f"{FILE_LOCATION}code/{title}"]
        elif file_extension == "py":
            cmd = ["/usr/local/munki/munki-python", f"{FILE_LOCATION}code/{title}"]
        elif file_extension == "go":
            cmd = ["go", "run", f"{FILE_LOCATION}code/{title}"]
        elif file_extension == "swift":
            cmd = ["swift", f"{FILE_LOCATION}code/{title}"]
        run_subp(cmd)
    if title == "Unity Bootstrap":
        logging.info("Running Unity Bootstrap demo")
        logging.info("Running demo")
        cmd = [
            "/usr/local/munki/munki-python",
            "/Library/CPE/bootstrap/cache/bootstrap-test-dialog.py",
        ]
        run_subp(cmd)

    return alert


### Main ###


def present():
    # Check for slide number argument
    if len(sys.argv) > 1:
        logging.info(f"Starting at slide {sys.argv[1]}")
        current_slide_index = int(sys.argv[1]) - 1
    else:
        current_slide_index = 0

    # search for json files in the same directory as this script
    json_files = glob.glob(f"{FILE_LOCATION}/slides/*.json")
    # sort by name
    json_files.sort()

    while current_slide_index < len(json_files):
        logging.info(f"Current slide: {current_slide_index + 1}")
        slide = json_files[current_slide_index]
        if (current_slide_index % 2) == 0:
            toggle_dark_mode("false")
        else:
            toggle_dark_mode("true")

        results = run_slide(slide)

        # Processing for Input slide
        if "Name" in results["stdout"].decode("utf-8"):
            logging.info("User entered name")
            output = json.loads(results["stdout"].decode("utf-8"))
            logging.info(f"Output: {output}")
            slide = DialogAlert()
            slide.content_dict["title"] = "Off you go."
            slide.content_dict["messagefont"] = "size=40"
            slide.content_dict["iconsize"] = "300"
            slide.content_dict[
                "icon"
            ] = "SF=person.badge.shield.checkmark.fill, color=green"
            slide.content_dict[
                "message"
            ] = f"Hello {output['Name']}! \n\n I see that you are here to {output['Quest']}. \n\n Your favourite colour is {output['Favourite Colour']}."
            alert = slide.alert(slide.content_dict)

        # User CMD-Q'd or it crashed or something
        if results["status"] == 10:
            logging.info("User quit slideshow")
            toggle_dark_mode("true")
            exit()
        while results["status"] != 0:
            logging.info("Waiting for user to click button")
            if results["status"] == 2:
                # Button 2
                logging.info("User clicked back")
                if current_slide_index > 0:
                    current_slide_index -= 1
                break  # Break out of the inner while loop
            if results["status"] == 3:
                # Button 3
                logging.info("User clicked more info")
            if results["status"] == 4:
                # Timer ran out
                current_slide_index += 1
                break
        else:
            # Button 1
            if current_slide_index == len(json_files) - 1:
                logging.info("End of slideshow")
                toggle_dark_mode("true")
                exit()
            current_slide_index += 1


if __name__ == "__main__":
    setup_logging()
    try:
        present()
    except Exception as e:
        logging.error(e)
        sys.exit(1)
