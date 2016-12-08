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
functions like [`generate`](#generate) and [`initialSeed`](#initialSeed).
-}
type alias GenericRng a = Seed -> (a, Seed)

{-| Int만 만들 수 있는 Rng -}
type alias IntRng = GenericRng Int

{-| Transform the values produced by a generator. The following examples show
how to generate booleans and letters based on a basic integer generator. -}
mapRng : (Int -> msg) -> IntRng -> GenericRng msg
mapRng func genA =
  \seed0 ->
    let (a, seed1) = genA seed0
    in (func a, seed1)

{-| Generate 32-bit integers in `[0, 10000)` -}
intRng : IntRng
intRng seed =
  let
    lo = 0
    hi = 10000
    k = hi - lo + 1
    base = 2147483561 -- 2^31 - 87

    iLogBase : Int -> Int -> Int
    iLogBase b i =
      if i < b then 1
      else 1 + iLogBase b (i // b)

    n = iLogBase base k

    f : Int -> Int -> State -> (Int, State)
    f n acc state =
      case n of
        0 -> (acc, state)
        _ ->
          let
            (x, nextState) = seed.next state
          in
            f (n - 1) (x + acc * base) nextState

    (v, nextState) = f n 1 seed.state
  in
    (
      lo + v % k,
      { seed | state = nextState }
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

{-| Rng의 State -}
type alias State = (Int, Int)

{-| Produce the initial generator state. Distinct arguments should be likely to
produce distinct generator states.  -}
initState : Int -> State
initState seed =
  let
    s = max seed -seed
    q  = s // (magicNum6-1)
    s1 = s %  (magicNum6-1)
    s2 = q %  (magicNum7-1)
  in
    (s1 + 1, s2 + 1)


{-| A `Seed` is the source of randomness in this whole system. Whenever you want
to use a generator, you need to pair it with a seed. -}
type alias Seed =
  {
    state : State,
    next  : State -> (Int, State)
  }

{-| Create a `seed` of randomness which makes it possible to
generate random values. If you use the same seed many times, it will result
in the same thing every time! A good way to get an unexpected seed is to use
the current time.
-}
initialSeed : Int -> Seed
initialSeed n =
  {
    state = initState n,
    next = next
  }


{-| Generate a random value as specified by a given `GenericRng`.

In the following example, we are trying to generate a number between 0 and 100
with the `int 0 100` generator. Each time we call `step` we need to provide a
seed. This will produce a random number and a *new* seed to use if we want to
run other generators later.

So here it is done right, where we get a new seed from each `step` call and
thread that through.

    seed0 = initialSeed 31415

    -- step (int 0 100) seed0 ==> (42, seed1)
    -- step (int 0 100) seed1 ==> (31, seed2)
    -- step (int 0 100) seed2 ==> (99, seed3)

Notice that we use different seeds on each line. This is important! If you use
the same seed, you get the same results.

    -- step (int 0 100) seed0 ==> (42, seed1)
    -- step (int 0 100) seed0 ==> (42, seed1)
    -- step (int 0 100) seed0 ==> (42, seed1)
-}
step : IntRng -> Seed -> (Int, Seed)
step generator seed = generator seed

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


--
-- Effect Manager
--
{-| Create a command that will generate random values.

Read more about how to use this in your programs in [The Elm Architecture
tutorial][arch] which has a section specifically [about random values][rand].

[arch]: https://evancz.gitbooks.io/an-introduction-to-elm/content/architecture/index.html
[rand]: https://evancz.gitbooks.io/an-introduction-to-elm/content/architecture/effects/random.html
-}
generate : (Int -> msg) -> Cmd msg
generate tagger =
  command (MakeMyCmd (mapRng tagger intRng))


type MyCmd msg = MakeMyCmd (GenericRng msg)


cmdMap : (Int -> Int) -> MyCmd Int -> MyCmd Int
cmdMap func (MakeMyCmd generator) =
  MakeMyCmd (mapRng func generator)


init : Task Never Seed
init =
  Time.now
    |> Task.andThen (\t -> Task.succeed (initialSeed (round t)))


onEffects : Platform.Router Int Never -> List (MyCmd Int) -> Seed -> Task Never Seed
onEffects router commands seed =
  case commands of
    [] ->
      Task.succeed seed

    MakeMyCmd generator :: rest ->
      let
        (value, newSeed) =
          step generator seed
      in
        Platform.sendToApp router value
          |> Task.andThen (\_ -> onEffects router rest newSeed)


onSelfMsg : Platform.Router msg Never -> Never -> Seed -> Task Never Seed
onSelfMsg _ _ seed =
  Task.succeed seed
