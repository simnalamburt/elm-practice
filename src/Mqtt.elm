{-
Copyright 2016 Hyeon Kim

Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
<LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
option. This file may not be copied, modified, or distributed
except according to those terms.
-}

effect module Mqtt where { command = MyCmd }
  exposing (
    random
  )

{-| This package is client library for [MQTT] protocol. It is based on the
[MQTT.js] project.

# Placeholder
@docs random

[MQTT]: http://mqtt.org/
[MQTT.js]: https://github.com/mqttjs/MQTT.js
-}

import Task exposing (Task)
import Native.Mqtt

-- Commands
type MyCmd msg = Generate

-- Effect Manager
type alias State = ()
type alias Msg = Never

init : Task Never State
init = Task.succeed ()

-- Handle App Messages
onEffects
  : Platform.Router msg Msg
  -> List (MyCmd msg)
  -> State
  -> Task Never State
onEffects router cmds state =
  Task.succeed ()

-- Handle Self Messages
onSelfMsg
  : Platform.Router msg Msg
  -> Msg
  -> State
  -> Task Never State
onSelfMsg router msg state =
  Task.succeed ()

-- TODO: What's this?
cmdMap : ()
cmdMap = ()



{-| A placeholder function for early-development stage.  -}
random : Cmd msg
random = command Generate
