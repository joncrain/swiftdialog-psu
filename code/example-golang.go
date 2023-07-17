package main

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
)

const (
	dialogCommand       = "/usr/local/bin/dialog"
	dialogCommandFile   = "/var/tmp/dialog.log"
	imgLocationRelative = "imgs"
)

type DialogAlert struct {
	ContentDict map[string]interface{}
}

func NewDialogAlert() *DialogAlert {
	// Set the default look of the alert
	contentDict := make(map[string]interface{})
	contentDict["button1text"] = "Continue"
	contentDict["button2text"] = "Back"
	contentDict["height"] = "500"
	contentDict["width"] = "900"
	contentDict["icon"] = filepath.Join(getFileLocation(), imgLocationRelative, "2023 MacAdmins Logo-Circle-Black.png")
	contentDict["iconsize"] = "300"
	contentDict["title"] = "none"
	contentDict["message"] = "none"
	contentDict["messagefont"] = "size=16"

	return &DialogAlert{
		ContentDict: contentDict,
	}
}

func (da *DialogAlert) Alert(contentDict map[string]interface{}, background bool) map[string]interface{} {
	jsonString, err := json.Marshal(contentDict)
	if err != nil {
		log.Fatal(err)
	}

	cmd := exec.Command(dialogCommand, "-o", "-p", "--jsonstring", string(jsonString), "--json")
	if background {
		err := cmd.Start()
		if err != nil {
			log.Fatal(err)
		}
		return nil
	}

	out, err := cmd.Output()
	resultDict := make(map[string]interface{})
	if err == nil {
		resultDict["stdout"] = out
	} else {
		resultDict["stderr"] = err.Error()
	}

	resultDict["status"] = cmd.ProcessState.ExitCode()
	resultDict["success"] = cmd.ProcessState.Success()

	return resultDict
}

func (da *DialogAlert) UpdateDialog(command, value string) {
	file, err := os.OpenFile(dialogCommandFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		log.Fatal(err)
	}
	defer file.Close()

	commandLine := fmt.Sprintf("%s: %s\n", command, value)
	_, err = file.WriteString(commandLine)
	if err != nil {
		log.Fatal(err)
	}
}

func main() {
	newAlert := NewDialogAlert()
	newAlert.ContentDict["title"] = "Hello World"
	newAlert.ContentDict["message"] = "This is a Go Example"
	status := newAlert.Alert(newAlert.ContentDict, false)
	fmt.Println(status)
}

func getFileLocation() string {
	ex, err := os.Executable()
	if err != nil {
		log.Fatal(err)
	}
	exPath := filepath.Dir(ex)
	return exPath
}
