package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"strings"

	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

var clients = make(map[*websocket.Conn]bool)
var broadcast = make(chan []byte)

type Message struct {
	Username string `json:"username"`
	Message  string `json:"message"`
}

func main() {
	http.Handle("/3d/", http.StripPrefix("/3d/", http.FileServer(http.Dir("3d"))))
	http.HandleFunc("/", homePage)
	http.HandleFunc("/filelist", fileList)
	http.HandleFunc("/ws", handleConnections)

	go handleMessages()

	fmt.Println("Server started on :80")
	err := http.ListenAndServe(":80", nil)
	if err != nil {
		panic("Error starting server: " + err.Error())
	}
}

func homePage(w http.ResponseWriter, r *http.Request) {
	http.ServeFile(w, r, "index.html")
}

func fileList(w http.ResponseWriter, r *http.Request) {
	files, err := ioutil.ReadDir("3d")
	if err != nil {
		fmt.Println(err)
		return
	}

	var fileList []string
	for _, file := range files {
		// ignore files that are not .glb
		if !strings.HasSuffix(file.Name(), ".glb") {
			continue
		}
		fileList = append(fileList, file.Name())
	}

	json, err := json.Marshal(fileList)
	if err != nil {
		fmt.Println(err)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.Write(json)
}

func handleConnections(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		fmt.Println(err)
		return
	}
	defer conn.Close()

	clients[conn] = true

	for {
		_, msg, err := conn.ReadMessage()
		if err != nil {
			fmt.Println(err)
			delete(clients, conn)
			return
		}
		print(string(msg) + "\n")
		broadcast <- msg
	}
}

func handleMessages() {
	for {
		msg := <-broadcast

		for client := range clients {
			err := client.WriteMessage(websocket.TextMessage, msg)
			if err != nil {
				fmt.Println(err)
				client.Close()
				delete(clients, client)
			}
		}
	}
}
