// Package workerpool provides a bounded worker pool for executing tasks
// concurrently while limiting the number of active goroutines.
// This prevents memory exhaustion and API rate-limiting when processing
// large batches of work (e.g., CSV rows, news articles, sentiment analysis).
package workerpool

import (
	"context"
	"sync"
)

// Task represents a unit of work. The function is executed by a worker
// goroutine and should respect the provided context for cancellation.
type Task func(ctx context.Context) error

// Result holds the outcome of a single task execution.
type Result struct {
	Index int   // original index within the submitted batch
	Err   error // nil on success
}

// Pool manages a fixed number of worker goroutines that pull tasks from a
// shared channel. Use New to create a pool and Submit / Wait to drive it.
type Pool struct {
	workers int
	tasks   chan indexedTask
	results chan Result
	wg      sync.WaitGroup
	ctx     context.Context
	cancel  context.CancelFunc
}

type indexedTask struct {
	index int
	fn    Task
}

// New creates a pool with the given number of workers and starts them.
// The context controls the lifetime of all workers – cancel it to
// drain remaining tasks without executing them.
func New(ctx context.Context, workers int) *Pool {
	ctx, cancel := context.WithCancel(ctx)
	p := &Pool{
		workers: workers,
		tasks:   make(chan indexedTask, workers*2), // small buffer to keep workers busy
		results: make(chan Result, workers*2),
		ctx:     ctx,
		cancel:  cancel,
	}
	for i := 0; i < workers; i++ {
		go p.worker()
	}
	return p
}

// Submit enqueues a task. It blocks if the task channel buffer is full,
// and returns immediately with a context error if the pool is cancelled.
func (p *Pool) Submit(index int, fn Task) error {
	select {
	case <-p.ctx.Done():
		return p.ctx.Err()
	case p.tasks <- indexedTask{index: index, fn: fn}:
		p.wg.Add(1)
		return nil
	}
}

// Wait closes the task channel, waits for all in-flight work to finish,
// then closes the results channel. Call this exactly once after all
// Submit calls are done.
func (p *Pool) Wait() {
	close(p.tasks)
	p.wg.Wait()
	close(p.results)
}

// Results returns the channel from which callers can read each Result.
// It is safe to range over this channel after calling Wait (the channel
// will be closed when all results have been sent).
func (p *Pool) Results() <-chan Result {
	return p.results
}

// Cancel stops the pool and prevents pending tasks from executing.
func (p *Pool) Cancel() {
	p.cancel()
}

func (p *Pool) worker() {
	for t := range p.tasks {
		var err error
		select {
		case <-p.ctx.Done():
			err = p.ctx.Err()
		default:
			err = t.fn(p.ctx)
		}
		p.results <- Result{Index: t.index, Err: err}
		p.wg.Done()
	}
}

// Run is a convenience helper that submits all tasks, waits for
// completion, and returns the collected results ordered by index.
// It is the simplest way to use the pool for a known batch of work.
func Run(ctx context.Context, workers int, tasks []Task) []Result {
	p := New(ctx, workers)

	go func() {
		for i, t := range tasks {
			if err := p.Submit(i, t); err != nil {
				break
			}
		}
		p.Wait()
	}()

	results := make([]Result, len(tasks))
	for r := range p.Results() {
		results[r.Index] = r
	}
	return results
}
