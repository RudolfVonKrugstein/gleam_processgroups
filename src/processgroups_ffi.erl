-module(processgroups_ffi).
-export([pid_decoder/1]).

pid_decoder(Pid) when is_pid(Pid) -> {ok, Pid};
pid_decoder(_Pid) -> {error, nil}.
