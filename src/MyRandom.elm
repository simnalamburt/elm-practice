effect module MyRandom where { command = MyCmd } exposing (generate)
{-|

effect module은 아래의 세 방식중 하나를 선택해서 선언해야한다.

    -- command만 있음
    effect module MyModule where { command = MyCmd } exposing ..

    -- subscription만 있음
    effect module MyModule where { subscription = MySub } exposing ..

    -- 둘다있음
    effect module MyModule where
      { command = MyCmd, subscription = MySub } exposing ..

`command`와 `subscription` 둘중 최소한 하나는 구현해야한다. 이 `command`,
`subscription`들을 Elm에선 "settings"라고 부른다.

effect module을 선언하면, 기본적으로 아래의 세 함수를 구현할 의무가 생긴다.

    init : Platform.Task Never a

    onEffects

    onSelfMsg : Platform.Router a b -> b -> c -> Platform.Task Never c

`onEffects` 함수의 타입은, settings에 따라 아래의 셋중 하나가 된다.

    -- command만 있음
    onEffects : Platform.Router a b -> List (MyCmd a)
                -> c -> Platform.Task Never c

    -- subscription만 있음
    onEffects : Platform.Router a b -> List (MySub a)
                -> c -> Platform.Task Never c

    -- 둘다있음
    onEffects : Platform.Router a b -> List (MyCmd a) -> List (MySub a)
                -> c -> Platform.Task Never c

`init`, `onEffects`, `onSelfMsg` 함수의 타입은 컴파일러에 의해 강제된다.

setting에 따라 아래의 함수들 또한 구현해야한다.

    -- command가 있을 경우 구현해야함
    cmdMap : (a -> b) -> MyCmd a -> MyCmd b

    -- subscription이 있을 경우 구현해야함
    subMap : (a -> b) -> MySub a -> MySub b

위의 두 함수는 컴파일러가 타입을 강제하지는 않는다. 허나 위의 모양대로 선언하지
않으면 모듈이 작동하지 않을 수 있다.

Effect module을 선언하면 구현해야하는 함수도 생기지만, 컴파일러가 개발자에게
주는 함수도 생긴다. setting에 따라, 아래의 함수들이 주어진다.

    -- command가 있을 경우 주어짐
    command : MyCmd msg -> Cmd msg

    -- subscription이 있을 경우 주어짐
    subscription : MySub msg -> Sub msg

어디에도 위의 두 함수의 동작이 문서화되어있지 않아 명확치는 않으나, 각각 MyCmd를
Cmd로 매핑해주고, MySub을 Sub으로 매핑해주는 함수인것으로 보인다.

-}
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

{-| Generate a random value between 0 and 10000

In the following example, we are trying to generate a number between 0 and 10000
with the `intRng` generator. Each time we call `intRng` we need to provide a
state. This will produce a random number and a *new* state to use if we want to
run other generators later.

So here it is done right, where we get a new state from each `intRng` call and
thread that through.

    state0 = initialState 12345

    -- intRng state0 ==> (1594, state1)
    -- intRng state1 ==> (2399, state2)
    -- intRng state2 ==> (8750, state3)

Notice that we use different states on each line. This is important! If you use
the same state, you get the same results.

    -- intRng state0 ==> (1594, state1)
    -- intRng state0 ==> (1594, state1)
    -- intRng state0 ==> (1594, state1)
-}
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
        (value, newState) = generator state
      in
        Platform.sendToApp router value
          |> Task.andThen (\_ -> onEffects router rest newState)


onSelfMsg : Platform.Router msg Never -> Never -> State -> Task Never State
onSelfMsg _ _ state =
  Task.succeed state
