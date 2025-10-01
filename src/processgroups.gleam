import gleam/dynamic
import gleam/dynamic/decode
import gleam/erlang/atom
import gleam/erlang/process
import gleam/erlang/reference.{type Reference}

/// A scope for process groups is an atom, we type alias to make it clearer
pub type Scope =
  atom.Atom

@external(erlang, "pg", "start_link")
pub fn start_link() -> Result(process.Pid, dynamic.Dynamic)

@external(erlang, "pg", "start_link")
pub fn start_link_with_scope(
  scope: Scope,
) -> Result(process.Pid, dynamic.Dynamic)

@external(erlang, "pg", "start")
pub fn start(scope: Scope) -> Result(process.Pid, dynamic.Dynamic)

@external(erlang, "pg", "join")
pub fn join(group: group, pid: process.Pid) -> Nil

@external(erlang, "pg", "join")
pub fn join_many(group: group, pids: List(process.Pid)) -> Nil

@external(erlang, "pg", "join")
pub fn join_scope(scope: Scope, group: group, pid: process.Pid) -> Nil

@external(erlang, "pg", "join")
pub fn join_scope_many(
  scope: Scope,
  group: group,
  pids: List(process.Pid),
) -> Nil

@external(erlang, "pg", "leave")
pub fn leave(group: group, pid: process.Pid) -> Nil

@external(erlang, "pg", "leave")
pub fn leave_scope(scope: Scope, group: group, pid: process.Pid) -> atom.Atom

@external(erlang, "pg", "leave")
pub fn leave_many(group: group, pids: List(process.Pid)) -> Nil

@external(erlang, "pg", "leave")
pub fn leave_many_scope(
  scope: Scope,
  group: group,
  pids: List(process.Pid),
) -> atom.Atom

/// For monitoring, we use the `gleam/erlang/process`
/// module and their way of handling messages.
/// The GroupMonitor type is constructed when monitoring
/// a process group. You can than use `selecting_process_group_monitor`
/// To receive `GroupMonitorEvent` messages using `gleam/erlang/process.select`.
pub opaque type GroupMonitor(group) {
  GroupMonitor(tag: Reference, group: group)
}

/// The events send when monitoring a process group.
pub type GroupMonitorEvent(group) {
  /// Some processes have joined
  ProcessJoined(group: group, pids: List(process.Pid))
  /// Same process have left
  ProcessLeft(group: group, pids: List(process.Pid))
}

pub fn monitor(group: group) -> #(GroupMonitor(group), List(process.Pid)) {
  let #(ref, pids) = erlang_monitor(group)
  #(GroupMonitor(tag: ref, group: group), pids)
}

@external(erlang, "pg", "monitor")
fn erlang_monitor(group: group) -> #(Reference, List(process.Pid))

pub fn monitor_scope(
  scope: Scope,
  group: group,
) -> #(GroupMonitor(group), List(process.Pid)) {
  let #(ref, pids) = erlang_monitor_scope(scope, group)
  #(GroupMonitor(tag: ref, group: group), pids)
}

@external(erlang, "pg", "monitor")
pub fn erlang_monitor_scope(
  scope: Scope,
  group: group,
) -> #(Reference, List(process.Pid))

/// Receive monitoring events.
///
/// # Example
///
/// ```
/// import pg_for_gleam as pg
/// import gelam/erlang/process
///
/// let monitor = pg.monitor(SomeProcessGroup)
///
/// let selector = pg.selecting_process_group_monitor(
///   selector: new_selector(),
///   monitor: monitor,
///   mapping: fn(gme) {gme}
/// )
///
/// case select(selector) {
///   Ok(ProcessJoined(_, pids)) -> io.print("some process joined")
///   Ok(ProcessLeft(_, pids)) -> io.print("some process left")
///   _ -> panic
/// }
/// ```
pub fn selecting_process_group_monitor(
  selector: process.Selector(payload),
  monitor: GroupMonitor(group),
  mapping: fn(GroupMonitorEvent(group)) -> payload,
) -> process.Selector(payload) {
  // monitoring sends 4-tuples, see https://www.erlang.org/doc/man/pg.html#monitor_scope-0
  process.select_record(selector, monitor.tag, 3, fn(record: dynamic.Dynamic) {
    let assert Ok(event) =
      decode.run(record, decode.field(1, decode.dynamic, decode.success))
    let assert Ok(pids) =
      decode.run(record, decode.field(3, decode.dynamic, decode.success))

    let event = atom.cast_from_dynamic(event)

    let assert Ok(pids) =
      decode.run(pids, decode.list(pid_decoder(process.self())))

    let payload = case atom.to_string(event) {
      "join" -> ProcessJoined(monitor.group, pids)
      "leave" -> ProcessLeft(monitor.group, pids)
      _ -> panic
    }

    mapping(payload)
  })
}

@external(erlang, "pg", "demonitor")
pub fn demonitor(group: group) -> Bool

@external(erlang, "pg", "demonitor")
pub fn demonitor_scope(scope: Scope, group: group) -> Bool

@external(erlang, "pg", "get_local_members")
pub fn get_local_members(group: group) -> List(process.Pid)

@external(erlang, "pg", "get_local_members")
pub fn get_local_members_scope(scope: Scope, group: group) -> List(process.Pid)

@external(erlang, "pg", "get_members")
pub fn get_members(group: group) -> List(process.Pid)

@external(erlang, "pg", "get_members")
pub fn get_members_scope(scope: Scope, group: group) -> List(process.Pid)

@external(erlang, "pg", "which_groups")
pub fn which_groups() -> List(group)

@external(erlang, "pg", "which_groups")
pub fn which_groups_scope(scope: Scope) -> List(group)

fn pid_decoder(zero: process.Pid) {
  decode.new_primitive_decoder("pid", fn(d) {
    case check_pid(d) {
      Ok(pid) -> Ok(pid)
      Error(_) -> Error(zero)
    }
  })
}

@external(erlang, "processgroups_ffi", "pid_decoder")
fn check_pid(maybe_pid: dynamic.Dynamic) -> Result(process.Pid, Nil)
