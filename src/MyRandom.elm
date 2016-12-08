effect module MyRandom where { command = MyCmd } exposing (generate)

import Basics exposing (..)
import List exposing ((::))
import Platform
import Platform.Cmd exposing (Cmd)
import Task exposing (Task)
import Time
import Tuple


--
-- Definition of Rng and its types
--

{-| A `GenericRng` is like a recipe for generating certain random values.  So a
`IntRng` describes how to generate integers and a `GenericRng String` describes
how to generate strings.

To actually *run* a generator and produce the random values, you need to use
functions like [`generate`](#generate) and [`initialState`](#initialState).
-}
type alias GenericRng a = State -> (a, State)

{-| Int만 만들 수 있는 Rng -}
type alias IntRng = GenericRng Int

{-| Transform the values produced by a generator. The following examples show
how to generate booleans and letters based on a basic integer generator. -}
mapRng : (Int -> msg) -> IntRng -> GenericRng msg
mapRng func genA =
  \state0 ->
    let (a, state1) = genA state0
    in (func a, state1)

{-| Generate 32-bit integers in `[0, 10000)` -}
intRng : IntRng
intRng state =
  let
    iLogBase : Int -> Int -> Int
    iLogBase b i =
      if i < b then 1
      else 1 + iLogBase b (i // b)

    next : State -> (Int, State)
    next (state1, state2) =
      -- Div always rounds down and so random numbers are biased
      -- ideally we would use division that rounds towards zero so
      -- that in the negative case it rounds up and in the positive case
      -- it rounds down. Thus half the time it rounds up and half the time it
      -- rounds down
      let
        k1 = state1 // magicNum1
        rawState1 = magicNum0 * (state1 - k1 * magicNum1) - k1 * magicNum2
        newState1 = if rawState1 < 0 then rawState1 + magicNum6 else rawState1
        k2 = state2 // magicNum3
        rawState2 = magicNum4 * (state2 - k2 * magicNum3) - k2 * magicNum5
        newState2 = if rawState2 < 0 then rawState2 + magicNum7 else rawState2
        z = newState1 - newState2
        newZ = if z < 1 then z + magicNum8 else z
      in
        (newZ, (newState1, newState2))

    f : Int -> Int -> State -> (Int, State)
    f n acc state =
      case n of
        0 -> (acc, state)
        _ ->
          let
            (x, nextState) = next state
          in
            f (n - 1) (x + acc * base) nextState

    lo = 0
    hi = 10000
    k = hi - lo + 1
    base = 2147483561 -- 2^31 - 87
    n = iLogBase base k
    (v, nextState) = f n 1 state
  in
    (
      lo + v % k,
      nextState
    )


--
-- IMPLEMENTATION
--
magicNum0 = 40014
magicNum1 = 53668
magicNum2 = 12211
magicNum3 = 52774
magicNum4 = 40692
magicNum5 = 3791
magicNum6 = 2147483563
magicNum7 = 2147483399
magicNum8 = 2147483562

{-| A `State` is the source of randomness in this whole system. Whenever you want
to use a generator, you need to pair it with a state. -}
type alias State = (Int, Int)

{-| Produce the initial generator state. Create a `state` of randomness which
makes it possible to generate random values.

Distinct arguments should be likely to produce distinct generator states. If you
use the same state many times, it will result in the same thing every time!

A good way to get an unexpected state is to use the current time. -}
initialState : Int -> State
initialState state =
  let
    s = max state -state
    q  = s // (magicNum6-1)
    s1 = s %  (magicNum6-1)
    s2 = q %  (magicNum7-1)
  in
    (s1 + 1, s2 + 1)


{-| Generate a random value as specified by a given `GenericRng`.

In the following example, we are trying to generate a number between 0 and 100
with the `int 0 100` generator. Each time we call `step` we need to provide a
state. This will produce a random number and a *new* state to use if we want to
run other generators later.

So here it is done right, where we get a new state from each `step` call and
thread that through.

    state0 = initialState 31415

    -- step (int 0 100) state0 ==> (42, state1)
    -- step (int 0 100) state1 ==> (31, state2)
    -- step (int 0 100) state2 ==> (99, state3)

Notice that we use different states on each line. This is important! If you use
the same state, you get the same results.

    -- step (int 0 100) state0 ==> (42, state1)
    -- step (int 0 100) state0 ==> (42, state1)
    -- step (int 0 100) state0 ==> (42, state1)
-}
step : IntRng -> State -> (Int, State)
step generator state = generator state


--
-- Effect Manager
--
type MyCmd msg = MakeMyCmd (GenericRng msg)

{-| Create a command that will generate random values.

Read more about how to use this in your programs in [The Elm Architecture
tutorial][arch] which has a section specifically [about random values][rand].

[arch]: https://evancz.gitbooks.io/an-introduction-to-elm/content/architecture/index.html
[rand]: https://evancz.gitbooks.io/an-introduction-to-elm/content/architecture/effects/random.html
-}
generate : (Int -> msg) -> Cmd msg
generate tagger = command (MakeMyCmd (mapRng tagger intRng))


cmdMap : (Int -> msg) -> MyCmd Int -> MyCmd msg
cmdMap func (MakeMyCmd generator) = MakeMyCmd (mapRng func generator)


init : Task Never State
init =
  Time.now
    |> Task.andThen (\t -> Task.succeed (initialState (round t)))


onEffects : Platform.Router Int Never -> List (MyCmd Int) -> State -> Task Never State
onEffects router commands state =
  case commands of
    [] ->
      Task.succeed state

    MakeMyCmd generator :: rest ->
      let
        (value, newState) =
          step generator state
      in
        Platform.sendToApp router value
          |> Task.andThen (\_ -> onEffects router rest newState)


onSelfMsg : Platform.Router msg Never -> Never -> State -> Task Never State
onSelfMsg _ _ state =
  Task.succeed state
