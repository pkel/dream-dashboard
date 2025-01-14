module Store : sig
  module type S = sig
    val create_event : Event.t -> (unit, string) result Lwt.t
    val get_events : unit -> (Event.t list, string) result Lwt.t
  end

  module In_memory : S
end

val router :
  ?store:(module Store.S) ->
  ?prefix:string ->
  ?middlewares:Dream.middleware list ->
  unit ->
  Dream.middleware
(** A Dream middleware that will serve the dashboard under the [prefix]
    endpoint. If prefix is not specified, it will be [/dashboard] by default. *)

val analytics : ?store:(module Store.S) -> unit -> Dream.middleware

(** Private modules for tests only. *)
module Private : sig
  module Handler : sig
    val index : store:(module Store.S) -> prefix:string -> Dream.handler
  end
end
