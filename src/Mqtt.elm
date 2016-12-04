{-
Copyright 2016 Hyeon Kim

Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
<LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
option. This file may not be copied, modified, or distributed
except according to those terms.
-}

module Mqtt exposing (random)
{-| This package is client library for [MQTT] protocol. It is based on the
[MQTT.js] project.

# Placeholder
@docs random

[MQTT]: http://mqtt.org/
[MQTT.js]: https://github.com/mqttjs/MQTT.js
-}

import Native.Mqtt

{-| A placeholder function for early-development stage.  -}
random : () -> Float
random = Native.Mqtt.random
