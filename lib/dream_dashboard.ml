module Handler = struct
  let index _req = Dream.html (Index_template.render ())
end

module Router = struct
  let loader _root path _request =
    match Asset.read path with
    | None -> Dream.empty `Not_Found
    | Some asset -> Dream.respond asset

  let routes prefix middlewares =
    Dream.scope prefix middlewares
      [
        Dream.get "/" Handler.index;
        Dream.get "/assets/**" (Dream.static ~loader "");
      ]

  let router prefix middlewares = Dream.router [ routes prefix middlewares ]
end

let router ?(prefix = "/dashboard") ?(middlewares = []) () =
  Router.router prefix middlewares

module Private = struct
  module Handler = Handler
end
