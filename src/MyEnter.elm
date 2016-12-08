{-
Copyright 2016 Hyeon Kim

Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
<LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
option. This file may not be copied, modified, or distributed
except according to those terms.
-}

effect module MyEnter where { command = MyCmd } exposing (count)
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

유저에게 노출되는 함수는 `count` 단 하나뿐이지만, 이를 위해 많은 밑작업을
해줘야한다. -}

import Platform.Cmd exposing (Cmd)
import Task exposing (Task)


--
-- 카운터 정의
--
{-|

`GenericCounter`는 임의의 자료형의 숫자를 셀 수 있는 카운터를 말한다. 사용법은
아래와 같다.

    -- 타입변수에 Int를 넣어주면, 정수형을 세는 카운터가 된다.
    intCounter : GenericCounter Int

    -- 최초 state
    state0 = newState

    -- 카운터를 실행시킬때마다 업데이트된 새 state가 나오는데, 이를
    -- 다음 호출때 새로이 넣어줘야한다.
    intCounter state0   --> 0, state1
    intCounter state1   --> 1, state2
    intCounter state2   --> 2, state3
    intCounter state3   --> 3, state4
    intCounter state4   --> 4, state5

    -- 업데이트된 새 state를 다음번 호출에 쓰지 않고, 낡은 state를 함수에 넣으면
    -- 계속 같은 결과가 나온다
    intCounter state0   --> 0, state1
    intCounter state0   --> 0, state1
    intCounter state0   --> 0, state1

Elm은 함수가 사이드이펙트를 가질 수 없는 pure한 언어이기 때문에, 위와같이
호출할때마다 state를 입력받고 새 state를 반환하도록 설계한것이다.

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

    -- 0.0, 1.0, 2.0, 3.0, ...
    floatCounter : GenericCounter Float
    floatCounter = mapCounter toFloat intCounter

    -- "0", "1", "2", "3", ...
    stringCounter : GenericCounter String
    stringCounter = mapCounter toString intCounter

    -- Just 0, Just 1, Just 2, Just 3
    maybeCounter : GenericCounter (Maybe Int)
    maybeCounter = mapCounter Just intCounter

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


{-| 카운터를 받아, 새로운 타입의 카운터를 만들어주는 함수이다. 예를들어 아래와
같이 하면, `GenericCounter Int`를 `GenericCounter String`으로 바꿀 수 있다.

    -- 0, 1, 2, 3, ...
    intCounter : GenericCounter Int

    -- "0", "1", "2", "3", ...
    stringCounter : GenericCounter String
    stringCounter = mapCounter toString intCounter
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


{-| 제일 기본적인 카운터인 `GenericCounter Int`의 구현체이다. 이 함수에
`mapCounter` 함수를 씌워서 새로운 다른 카운터를 만들 수 있다. -}
intCounter : GenericCounter Int
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
{-| Elm이 시켜서 만든 타입. `type alias`로 선언할경우 컴파일에러가 나오므로,
반드시 그냥 `type`으로 만들어주도록 하자. -}
type MyCmd msg = MakeMyCmd (GenericCounter msg)

{-| 유저에게 노출되는 함수. 유저는 이 함수를 아래와 같은 방식으로 사용하게된다.

    type Msg = Count | NewCount Int

    update : Msg -> Model -> (Model, Cmd Msg)
    update msg model =
      case msg of
        Count -> (model, MyEnter.count NewCount)
        --               ^^^^^^^^^^^^^ ^^^^^^^^
        --               count 함수에  컨스트럭터를 넘기면

        NewCount number -> (Just number, Cmd.none)
        --^^^^^^
        -- Elm 런타임이 Int를 그 컨스트럭터로 감싸서 유저에게 돌려준다.
-}
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


{-| 프로그램이 켜진 직후 State가 어떤 값일지 정의하는 함수.

Task는 js의 promise, 러스트/스칼라의 future와 유사한 자료형인데, 자세한것은
[공식문서] 참고. 모나드 쓰듯이 Task.andThen으로 체이닝 해가며 사용하면 된다.

    someAsyncJob
      |> Tash.andThen anotherAsyncJob
      |> Tash.andThen blablaAsyncJob

[공식문서]: http://package.elm-lang.org/packages/elm-lang/core/latest/Task
-}
init : Task Never State
--          ^^^^^
-- 실패할리 없는 함수이므로, Task 타입의 첫번째 타입변수에 Never 타입이 들어갔다.
init = Task.succeed newState


{-| Elm 런타임에 의해 호출되는 함수이며, 상기했듯이 이펙트 매니저의 세팅에 따라
타입명세가 달라지는 함수.

함수의 첫번째 인자인 [Router]는 `MyEnter` Effect Manager가
`CommandExample.elm`과 같은 어플리케이션으로 메시지를 보낼때 사용하는 핸들이다.
이 타입 안의 값을 직접 조작할 일은 없고, `Platform.sendToApp` 혹은
`Platform.sendToSelf` 함수를 호출할때에 인자로만 쓰인다.

두번째 파라미터인 `List (MyCmd msg)` 는 현재 수행해야할 MyCmd(커맨드들)의
배열이다. 배열에 현재 수행해야 할 커맨드가 하나도 없다면, 바로 `Task.succeed
state`를 리턴하면 된다. 하지만 수행해야 할 커맨드가 하나 이상 있다면, 배열이 빌
때까지 onEffects 함수를 재귀출하여 모든 명령을 수행해야한다.

세번째 파라미터인 `State`는 말 그대로 `onEffects` 함수가 호출되는 시점의 현재
`State`이다. 맨 처음 `onEffects` 함수가 호출될 때엔 `init` 함수의 결과로 반환된
`State`가 파라미터로 주어지며, 그 다음번 `onEffects` 함수가 호출될때엔 직전의
`onEffects` 함수가 반환한 `State`가 파라미터로 주어진다.

리턴값으로는 MyCmd를 수행한 뒤 변화한 타입을 `Task err State`의 형태로 반환하면
된다. 단 본 예제의 경우 `onEffects` 함수가 실패할 수 없기때문에 `err` 타입변수에
`Never` 타입이 입력되어있다.

[Router]: http://package.elm-lang.org/packages/elm-lang/core/5.0.0/Platform#Router
-}
onEffects
  : Platform.Router msg Never -> List (MyCmd msg) -> State -> Task Never State
  --                    ^^^^^                                      ^^^^^
  -- 이 프로그램에선 SelfMsg가 없으므로, Router의 두번째 타입 변수에 Never
  -- 타입이 들어갔다. 마찬가지로 리턴값 역시, 실패할 리 없는 함수이므로 Task
  -- 타입의 첫번째 타입변수에 Never 타입이 들어갔다.
onEffects router commands state =
  case commands of
    -- 아무 커맨드가 없다.
    [] -> Task.succeed state

    MakeMyCmd generator :: rest ->
      let
        (value, newState) = generator state
      in
        Platform.sendToApp router value
          |> Task.andThen (\_ -> onEffects router rest newState)


{-| SelfMsg를 처리하는 함수

Platform.sendToApp 함수를 호출하면 앱에 메시지가 간다. Platform.sendToSelf
함수를 호출하면 전송한 메시지가 이 모듈에게 돌아온다. 이때 그 자기자신에게 보낸
메시지를 처리하는 함수가 바로 onSelfMsg 함수이다.

이 예제에서는 SelfMsg를 전송할 일이 없으므로, 단순히 입력받은 state를 바로
반환한것으로 구현하였다. -}
onSelfMsg : Platform.Router msg Never -> Never -> State -> Task Never State
--                              ^^^^^    ^^^^^
-- 절대 SelfMsg가 발생할 일이 없으므로, SelfMsg의 타입이 들어가야할 자리에 Never
-- 타입을 넣어주었다.
onSelfMsg _ _ state = Task.succeed state


{-| TODO: 뭐하는 함수인지 정확히 알아내기

라이브러리 개발자, 유저 둘 다 이 함수를 직접 호출할일이 없다. Elm 런타임이
호출하는 함수인것으로 보인다. `init`, `onEffects`, `onSelfMsg` 함수와는 달리 이
함수는 타입이 강제되지는 않으나, 아래의 꼴대로 정의되지 않으면 모듈이 제대로
작동하지 않는다.

공식문서에 이 함수에 관한 설명이 없어서, 어떻게 쓰이는 함수인지 알수가 없다. -}
cmdMap : (ty1 -> ty2) -> MyCmd ty1 -> MyCmd ty2
cmdMap fn (MakeMyCmd counter) = MakeMyCmd (mapCounter fn counter)
