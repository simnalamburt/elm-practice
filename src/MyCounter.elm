{-
Copyright 2016 Hyeon Kim

Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
<LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
option. This file may not be copied, modified, or distributed
except according to those terms.
-}

effect module MyCounter where { command = MyCmd } exposing (count)
{-|

Elm은 하스켈처럼, 모든 함수가 퓨어한 언어이다. 그래서 사이드이펙트를 가진
라이브러리를 만들으려면, 평범한 방법으로는 안된다. 모듈 선언도 `effect module`
이런식으로 특이하게 해야한다. 이를 Elm 커뮤니티에선 [Effect Manager]라고 부른다.

본 튜토리얼은 [Effect Manager]를 어떻게 사용하는지는 알고있다고 가정하고,
[Effect Manager]를 어떻게 만드는지에 초점을 맞춰 설명할것이다. 만약 아직
모른다면 아래의 두 링크를 참고하길 바란다.

- https://evancz.gitbooks.io/an-introduction-to-elm/content/architecture/index.html
- https://evancz.gitbooks.io/an-introduction-to-elm/content/architecture/effects/random.html

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

본 예제에서는 만들 수 있는 Effect Module중 가장 간단한 모듈인, "카운터"를
구현할것이다. 단순하게 버튼을 누를때마다 숫자가 계속 1씩 올라가는 모듈을
만들것이다. 함수마다 전부 주석을 달아두었으니, 차례대로 천천히 읽으면 이해에
도움이 될것이다.

-}

-- TODO: 필요없는거 지우기
import Basics exposing (..)
import List exposing ((::))
import Platform
import Platform.Cmd exposing (Cmd)
import Task exposing (Task)
import Time
import Tuple


--
-- 카운터 정의
--
{-|

`GenericCounter`는 임의의 자료형의 숫자를 셀 수 있는 카운터를 말한다. 사용법은
아래와 같다.

    -- 타입변수에 Int를 넣어주면, 정수형을 세는 카운터가 된다.
    intcounter : GenericCounter Int

    -- 최초 state
    state = newState

    TODO: 예시 만들기

타입변수에 다른 자료형을 넣어주면 아래와 같이 다양한 타입의 카운터를 만들 수
있다.

자료형                        | 세는 방식
------------------------------|-----------------------------
`GenericCounter Int`          | 0, 1, 2, 3, ...
`GenericCounter Float`        | 0.0, 1.0, 2.0, 3.0, ...
`GenericCounter String`       | "0", "1", "2", "3", ...
`GenericCounter (Maybe Int)`  | Just 0, Just 1, Just 2, Just 3, ...
`GenericCounter (MyType Int)` | My 0, My 1, My 2, My 3, ...

위와 같은 기본형이 아닌 복잡한 카운터는, `mapCounter` 함수를 써서 만들어줄 수
있다.

    TODO: 예시 만들기

어차피 정수형인 카운터를 위와같이 임의의 타입에 대해 구현할 수 있게 하는 이유는,
이렇게 해야만 유저가 `update`함수에서 이 모듈을 사용할 수 있기 때문이다.

    type Msg = Count
             | NewCount Int

    update : Msg -> Model -> (Model, Cmd Msg)
    update msg model =
      case msg of
        Count -> (model, count NewCount)
        NewCount number -> ({ model | count = number }, Cmd.none)

-}
type alias GenericCounter ty = State -> (ty, State)


{-|

카운터를 받아, 새로운 타입의 카운터를 만들어주는 함수이다. 예를들어 아래와 같이
하면, `GenericCounter Int`를 `GenericCounter String`으로 바꿀 수 있다.

    TODO: 설명

-}
mapCounter : (ty1 -> ty2) -> GenericCounter ty1 -> GenericCounter ty2
mapCounter mapFn original =
  -- mapper function과, 원래의 카운터 (original)을 받아 새 함수를 아래와 같이
  -- 람다로 만들어준다.
  \oldState ->
    let
      -- oldState를 원래의 카운터에 넣어서 결과물(oldResult)과 newState를 받은뒤
      (oldResult, newState) = original oldState
      -- oldResult를 mapper function에 집어넣어서 새 결과물(newResult)를 만든다
      newResult = mapFn oldResult
    in
      (newResult, newState)


{-| Int만 만들수 있는 카운터이다. 코드 길이가 지나치게 길어지는것을 막기위해
선언하였다. -}
type alias IntCounter = GenericCounter Int

{-| 제일 기본적인 카운터인 `GenericCounter Int`의 구현체이다. 이 함수에
`mapCounter` 함수를 씌워서 새로운 다른 카운터를 만들 수 있다. -}
intCounter : IntCounter
intCounter oldState =
  let
    -- 지금까지 몇번 세었는지 반환
    return = oldState.howMany
    -- 센 횟수에 1을 더해서 새 state를 만든다
    newState = { howMany = oldState.howMany + 1 }
  in
    (return, newState)

{-| Counter의 스테이트를 의미하는 타입이다. Counter의 상태는 당연히도 "지금까지
몇번 세었는가"가 전부이다. -}
type alias State = { howMany : Int }

{-| 새 스테이트를 만들어주는 함수이다. -}
newState : State
newState = { howMany = 0 }


--
-- Effect Manager
--
{-| TODO: 설명 -}
type MyCmd msg = MakeMyCmd (GenericCounter msg)

{-| TODO: 설명 -}
count : (Int -> msg) -> Cmd msg
count tagger =
  let
    -- tagger 함수는 유저가 제공한 함수로, Int 타입을 Msg 타입으로 바꿔준다.
    -- mapCounter로 tagger 함수를 intCounter에 입혀서, msgCounter 함수를
    -- 만들어줄 수 있게된다.
    --
    -- 만약 유저의 Msg 타입이 아래와 같은 꼴이라면, msgCounter는 아래와 같이
    -- 만들어진다.
    --
    --     type Msg = Noop
    --              | Result Int
    --
    --     msgCounter = mapCounter Result intCounter
    --
    --     intCounter    -- 0, 1, 2, 3, ...
    --     msgCounter    -- Result 0, Result 1, Result 2, Result 3, ...
    msgCounter : GenericCounter msg
    msgCounter = mapCounter tagger intCounter

    -- 만들어진 `GenericCounter msg`를 MakeMyCmd 컨스트럭터를 사용해
    -- `MyCmd msg` 타입으로 바꿔준다.
    myCmd : MyCmd msg
    myCmd = MakeMyCmd msgCounter

    -- 그리고 이를 Elm 컴파일러가 주는 `command` 함수를 써서 `Cmd msg` 타입으로
    -- 바꿔준다.
    result : Cmd msg
    result = command myCmd
  in
    result


{-| TODO: 설명 -}
cmdMap : (ty -> msg) -> MyCmd ty -> MyCmd msg
cmdMap fn (MakeMyCmd counter) = MakeMyCmd (mapCounter fn counter)


{-| TODO: 설명 -}
init : Task Never State
init = Task.succeed newState


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
