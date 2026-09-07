// Loopback-only, bounded fixture for observing HTTP connection cancellation.
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"sync"
	"sync/atomic"
	"time"
)

func main() {
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		panic(err)
	}
	var active, canceled, accepted atomic.Int64
	release := make(chan struct{})
	var once sync.Once
	unblock := func() { once.Do(func() { close(release) }) }
	mux := http.NewServeMux()
	server := &http.Server{Handler: mux, ReadHeaderTimeout: 2 * time.Second}
	mux.HandleFunc("/hold/responses", func(w http.ResponseWriter, r *http.Request) {
		// EOF lets net/http watch disconnects while the handler holds its reply.
		if _, err := io.Copy(io.Discard, http.MaxBytesReader(w, r.Body, 1<<20)); err != nil {
			http.Error(w, "invalid fixture body", http.StatusBadRequest)
			return
		}
		r.Body.Close()
		accepted.Add(1)
		active.Add(1)
		defer active.Add(-1)
		select {
		case <-r.Context().Done():
			canceled.Add(1)
			return
		case <-release:
		case <-time.After(10 * time.Second):
		}
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprint(w, `{"id":"fixture","status":"completed","output":[],"usage":{}}`)
	})
	mux.HandleFunc("/state", func(w http.ResponseWriter, r *http.Request) {
		json.NewEncoder(w).Encode(map[string]int64{"active": active.Load(), "canceled": canceled.Load(), "accepted": accepted.Load()})
	})
	mux.HandleFunc("/release", func(w http.ResponseWriter, r *http.Request) { unblock(); fmt.Fprint(w, "released") })
	mux.HandleFunc("/shutdown", func(w http.ResponseWriter, r *http.Request) {
		unblock()
		go func() {
			ctx, cancel := context.WithTimeout(context.Background(), time.Second)
			defer cancel()
			server.Shutdown(ctx)
		}()
	})
	go func() { time.Sleep(30 * time.Second); unblock(); server.Close() }()
	fmt.Println("http://" + listener.Addr().String())
	if err := server.Serve(listener); err != nil && err != http.ErrServerClosed {
		panic(err)
	}
}
