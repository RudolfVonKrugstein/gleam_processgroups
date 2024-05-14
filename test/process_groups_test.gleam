import gleam/erlang/process
import gleam/otp/task
import gleeunit
import gleeunit/should
import process_groups as pg

pub fn main() {
  gleeunit.main()
}

/// A type for identifying our
/// process groups. We just have one!
/// We could also use stings for this.
pub type ProcessGroups {
  TestGroup
}

/// Clear a process group, so that we have 
/// a known state before a test.
pub fn clear_group(group: group) {
  pg.leave_many(group, pg.get_members(group))
}

/// Join a process group and ensure the pid is in it.
pub fn join_test() {
  // setup
  let _ = pg.start_link()
  let pgroup = TestGroup
  clear_group(pgroup)

  // act
  pg.join(pgroup, process.self())

  // test
  should.equal(pg.get_members(pgroup), [process.self()])
}

/// List process groups
pub fn which_groups_test() {
  // seutp
  let _ = pg.start_link()
  let pgroup = TestGroup
  clear_group(pgroup)
  pg.join(pgroup, process.self())

  // act
  let group = pg.which_groups()

  // test
  should.equal(group, [TestGroup])
}

/// Leave a process group and ensure the pid is gone
pub fn leave_test() {
  // setup
  let _ = pg.start_link()
  let pgroup = TestGroup
  clear_group(pgroup)

  pg.join(pgroup, process.self())

  // act
  pg.leave(pgroup, process.self())

  // test
  should.equal(pg.get_members(pgroup), [])
}

/// Exit a process and therby leave a process group
pub fn leave_on_exit_test() {
  // setup
  let _ = pg.start_link()
  let pgroup = TestGroup
  clear_group(pgroup)

  // act
  let t = task.async(fn() { pg.join(pgroup, process.self()) })
  task.await(t, 100)

  // test
  should.equal(pg.get_members(pgroup), [])
}

/// Monitor a process group and ensure we are getting joined events
pub fn monitor_joined_test() {
  // setup
  let _ = pg.start_link()
  clear_group(TestGroup)
  pg.join(TestGroup, process.self())

  // act
  let #(monitor, pids) = pg.monitor(TestGroup)

  // start a process that joins the group
  let ppid =
    process.start(fn() { pg.join(TestGroup, process.self()) }, linked: True)
  let assert Ok(pg.ProcessJoined(TestGroup, new_pids)) =
    pg.selecting_process_group_monitor(
      process.new_selector(),
      monitor,
      fn(joined) { joined },
    )
    |> process.select(100)

  // test
  should.equal(pids, [process.self()])
  should.equal(new_pids, [ppid])
}

/// Monitor a process group and ensure we are getting leave events
pub fn monitor_left_test() {
  // setup
  let _ = pg.start_link()
  clear_group(TestGroup)

  // act
  let #(monitor, pids) = pg.monitor(TestGroup)

  // start a process that joins and leaves by exiting
  let ppid =
    process.start(fn() { pg.join(TestGroup, process.self()) }, linked: True)

  // selector for process groups monitor events
  let selector =
    pg.selecting_process_group_monitor(
      process.new_selector(),
      monitor,
      fn(event) { event },
    )

  // There should be a join event
  let assert Ok(pg.ProcessJoined(_, join_pids)) =
    selector
    |> process.select(100)

  // And a leave event
  let assert Ok(pg.ProcessLeft(_, leave_pids)) =
    selector
    |> process.select(100)

  // test
  should.equal(pids, [])
  should.equal(join_pids, [ppid])
  should.equal(leave_pids, [ppid])
}
