module Store = struct
  module type S = sig
    val create_event : Event.t -> (unit, string) result Lwt.t
    val get_events : unit -> (Event.t list, string) result Lwt.t
  end

  module In_memory : S = struct
    let events = ref []

    let create_event event =
      events := event :: !events;
      Lwt.return (Ok ())

    let get_events () = Lwt.return (Ok !events)
  end
end

module Handler = struct
  let index ~store ~prefix _req =
    let open Lwt.Syntax in
    let (module Repo : Store.S) = store in
    let* events = Repo.get_events () in
    match events with
    | Ok events -> Dream.html (Index_template.render ~prefix events)
    | Error _ ->
        Dream.respond ~code:500
          "could not get the list of events from the store"
end

module Middleware = struct
  let analytics store handler req =
    let open Lwt.Syntax in
    let ua = Dream.header "user-agent" req |> Option.map User_agent.parse in
    let* () =
      match ua with
      | None ->
          Logs.warn (fun m -> m "No user agent in the request headers");
          Lwt.return ()
      | Some x when User_agent.is_bot x ->
          Logs.warn (fun m -> m "Request is from a bot");
          Lwt.return ()
      | Some ua -> (
          let (module Repo : Store.S) = store in
          let url = Dream.target req in
          let referer = Dream.header "referer" req in
          let timestamp = Unix.gettimeofday () in
          let event = Event.{ url; ua; referer; timestamp } in
          let+ result = Repo.create_event event in
          match result with
          | Ok _ -> ()
          | Error err ->
              Logs.warn (fun m ->
                  m "An error occured while collecting analytics data: %s" err))
    in
    handler req
end

module Router = struct
  let loader _root path _request =
    match Asset.read path with
    | None -> Dream.empty `Not_Found
    | Some asset -> Dream.respond asset

  let routes prefix middlewares store =
    Dream.scope prefix middlewares
      [
        Dream.get "/" (Handler.index ~prefix ~store);
        Dream.get "/assets/**" (Dream.static ~loader "");
      ]

  let router prefix middlewares store =
    Dream.router [ routes prefix middlewares store ]
end

let router ?(store = (module Store.In_memory : Store.S))
    ?(prefix = "/analytics") ?(middlewares = []) () =
  Router.router prefix middlewares store

let analytics ?(store = (module Store.In_memory : Store.S)) () =
  Middleware.analytics store

module Private = struct
  module Handler = Handler
end
