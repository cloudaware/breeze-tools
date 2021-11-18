package main

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"time"
)

const (
	DEFAULT_PATH     = "/opt/breeze-agent/app.sh"
	DEFAULT_INTERVAL = 15
)

func main() {
	os.Setenv("PATH", "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin")
	appPath := os.Getenv("BREEZE_APP_PATH")
	if appPath == "" {
		appPath = DEFAULT_PATH
	}

	runInterval, err := strconv.Atoi(os.Getenv("BREEZE_RUN_INTERVAL"))
	if err != nil {
		runInterval = DEFAULT_INTERVAL
	}

	schedule := time.NewTicker(time.Duration(runInterval) * time.Minute)
	for ; true; <-schedule.C {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Minute)
		defer cancel()

		cmd := exec.CommandContext(ctx, appPath)
		out, err := cmd.CombinedOutput()

		if ctx.Err() == context.DeadlineExceeded {
			fmt.Println("Command timed out")
			continue
		}

		fmt.Println("Output:", string(out))
		if err != nil {
			fmt.Println("Non-zero exit code:", err)
		}
	}
}
