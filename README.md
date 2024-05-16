# process groups for gleam

Simple wrapper around [erlang process groups] in gleam.

This library mainly wraps [erlang process groups], so go to its documentation for details.

[![Package Version](https://img.shields.io/hexpm/v/process_groups)](https://hex.pm/packages/process_groups)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/process_groups/)

## Usage

Add this  library to your Gleam project

```sh
gleam add process_groups
```

And use it in your project

```gleam
import io
import process_groups as pg
import gleam/erlang/process

// some type we use to distinguish process groups
// could also be strings
type ProcessGroups {
    ExampleProcessGroup
}

pub fn main() {
    // start process groups
    pg.start_link()

    // put ourself into a process group
    pg.join(ExampleProcessGroup, process.self())

    // list processes in the group
    io.debug(pg.get_members(ExampleProcessGroup))
    // output: [<our-process-id>]

    // leave the group
    pg.leave(ExampleProcessGroup, process.self())

    // list processes in the group
    io.debug(pg.get_members(ExampleProcessGroup))
    // output: []

    // monitor a process group
    let #(group_monitor, current_processes) = pg.monitor(ExampleProcessGroup)
    io.debug(current_processes)
    // output: []
    
    // join to create monitoring event
    pg.join(ExampleProcessGroup, process.self())

    // get the created event
    let assert Ok(pg.ProcessJoined(ExampleProcessGroup, new_pids)) = pg.selecting_process_group_monitor(
      process.new_selector(),
      group_monitor,
      fn(pid) {pid}
    ) |> process.select(100)
}
```


Further documentation can be found at <https://hexdocs.pm/process_groups>.

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
gleam shell # Run an Erlang shell
```

[erlang process groups]: https://www.erlang.org/doc/man/pg.html
