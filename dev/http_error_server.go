// Bounded, loopback-only provider HTTP error fixture; never calls a model.
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"strings"
	"sync"
	"time"
)

func main() {
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		panic(err)
	}
	var mu sync.Mutex
	counts := map[string]int{}
	held, canceled := 0, 0
	release := make(chan struct{})
	var once sync.Once
	unblock := func() { once.Do(func() { close(release) }) }
	mux := http.NewServeMux()
	server := &http.Server{Handler: mux, ReadHeaderTimeout: 2 * time.Second}
	mux.HandleFunc("/counts", func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		defer mu.Unlock()
		json.NewEncoder(w).Encode(map[string]any{"requests": counts, "held": held, "canceled": canceled})
	})
	mux.HandleFunc("/release", func(w http.ResponseWriter, r *http.Request) { unblock() })
	mux.HandleFunc("/shutdown", func(w http.ResponseWriter, r *http.Request) {
		unblock()
		go func() {
			ctx, cancel := context.WithTimeout(context.Background(), time.Second)
			defer cancel()
			server.Shutdown(ctx)
		}()
	})
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if _, err := io.Copy(io.Discard, http.MaxBytesReader(w, r.Body, 1<<20)); err != nil {
			http.Error(w, "bad body", 400)
			return
		}
		r.Body.Close()
		parts := strings.Split(strings.Trim(r.URL.Path, "/"), "/")
		if len(parts) < 2 {
			http.NotFound(w, r)
			return
		}
		key, kind := parts[0]+"/"+parts[1], parts[1]
		mu.Lock()
		counts[key]++
		mu.Unlock()
		w.Header().Set("Content-Type", "application/json")
		switch kind {
		case "quota":
			w.WriteHeader(429)
			fmt.Fprint(w, `{"error":{"code":"insufficient_quota","message":"quota exhausted"}}`)
		case "auth":
			w.WriteHeader(401)
			fmt.Fprint(w, `{"error":{"code":"invalid_api_key","message":"invalid key"}}`)
		case "rate":
			w.Header().Set("Retry-After", "0.02")
			w.WriteHeader(429)
			fmt.Fprint(w, `{"error":{"code":"rate_limit","message":"rate limit"}}`)
		case "held":
			w.WriteHeader(401)
			fmt.Fprint(w, `{"error":`)
			w.(http.Flusher).Flush()
			mu.Lock()
			held++
			mu.Unlock()
			defer func() { mu.Lock(); held--; mu.Unlock() }()
			select {
			case <-r.Context().Done():
				mu.Lock()
				canceled++
				mu.Unlock()
			case <-release:
			case <-time.After(10 * time.Second):
			}
		default:
			http.NotFound(w, r)
		}
	})
	go func() { time.Sleep(60 * time.Second); unblock(); server.Close() }()
	fmt.Println("http://" + listener.Addr().String())
	if err := server.Serve(listener); err != nil && err != http.ErrServerClosed {
		panic(err)
	}
}
