{- TODO: 저작권 명시 -}
effect module MyKeyboard where { subscription = MySub } exposing (downs)
{-| TODO: 모듈레벨 설명 보충 -}

import Dict
import Dom.LowLevel as Dom
import Json.Decode as Json
import Process
import Task exposing (Task)


{-| TODO: 설명 -}
type alias Watcher msg =
  {
    taggers : List msg,
    pid : Process.Id
  }


{-| 이 모듈의 State를 의미하는 타입이다. Watcher가 존재하는지 여부를 기억한다. -}
type alias State msg = Maybe (Watcher msg)

{-| TODO: 설명 -}
type SelfMsg = MakeSelfMsg


--
-- EFFECT MANAGER
--
{-| Elm이 시켜서 만든 타입. `type alias`로 선언할경우 컴파일에러가 나오므로,
반드시 그냥 `type`으로 만들어주도록 하자. -}
type MySub msg = MakeMySub msg

{-| TODO: 함수 설명 보충

Subscribe to get codes whenever a key goes down. 유저에게 노출되는 유일한
함수이다. -}
downs : msg -> Sub msg
downs tagger = subscription (MakeMySub tagger)


{-| 프로그램이 켜진 직후 State가 어떤 값일지 정의하는 함수.

Task는 js의 promise, 러스트/스칼라의 future와 유사한 자료형인데, 자세한것은
[공식문서] 참고. 모나드 쓰듯이 Task.andThen으로 체이닝 해가며 사용하면 된다.

    someAsyncJob
      |> Tash.andThen anotherAsyncJob
      |> Tash.andThen blablaAsyncJob

[공식문서]: http://package.elm-lang.org/packages/elm-lang/core/latest/Task
-}
init : Task Never (State msg)
--          ^^^^^
-- 실패할리 없는 함수이므로, Task 타입의 첫번째 타입변수에 Never 타입이 들어갔다.
init = Task.succeed Nothing


{-| Elm 런타임에 의해 호출되는 함수이며, 상기했듯이 이펙트 매니저의 세팅에 따라
타입명세가 달라지는 함수.

함수의 첫번째 인자인 [Router]는 `MyCounter` Effect Manager가
`CommandExample.elm`과 같은 어플리케이션으로 메시지를 보낼때 사용하는 핸들이다.
이 타입 안의 값을 직접 조작할 일은 없고, `Platform.sendToApp` 혹은
`Platform.sendToSelf` 함수를 호출할때에 인자로만 쓰인다.

TODO: `List (MySub msg)` 설명 보충

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
  : Platform.Router msg SelfMsg -> List (MySub msg) -> State msg -> Task Never (State msg)
  --                                                                     ^^^^^
  -- 이 모듈의 onEffects는 절대 실패하지 않는다. 그러므로 Task 타입의 첫번째
  -- 타입변수에 Never 타입이 들어갔다.
onEffects router newSubs oldState =
  -- TODO: 이벤트핸들러 붙였다 떼었다 하면서 테스트하기
  let
    -- MySub 안에 들어있는 msg들을 모두 꺼내, List msg로 모은다
    newTaggers : List msg
    newTaggers = List.map (\(MakeMySub msg) -> msg) newSubs

    -- pid를 입력하면 newTaggers
    newWatcher : Process.Id -> Task Never (State msg)
    newWatcher pid = Task.succeed (Just (Watcher newTaggers pid))

    -- TODO: 코드 순서 바꾸기
    updateProcess : Watcher msg -> Task Never (State msg)
    updateProcess {pid} = newWatcher pid

    createProcess : Task Never (State msg)
    createProcess =
      let
        -- 별 의미없이 있는 함수. 원래는 onDocument 콜백의 결과로 주어지는
        -- 키코드를 파싱하는데 쓰는 함수지만, 본 예제에선 키코드 값을 버리므로
        -- 의미가 없다.
        -- Reference: http://package.elm-lang.org/packages/elm-lang/core/5.0.0/Json-Decode
        keyCode : Json.Decoder ()
        keyCode = Json.succeed ()

        -- onDocument 함수에 넣을 콜백함수
        callBack : () -> Task Never ()
        callBack () = Platform.sendToSelf router MakeSelfMsg

        -- onDocument 호출로 생성한 프로미스
        -- Reference: http://package.elm-lang.org/packages/elm-lang/dom/1.1.1/Dom-LowLevel#onDocument
        promise : Task Never Never
        promise = Dom.onDocument "keydown" keyCode callBack
      in
        Process.spawn promise
        |> Task.andThen newWatcher
  in
    case oldState of
      Nothing   -> createProcess
      Just left -> updateProcess left


{-| SelfMsg를 처리하는 함수

Platform.sendToApp 함수를 호출하면 앱에 메시지가 간다. Platform.sendToSelf
함수를 호출하면 전송한 메시지가 이 모듈에게 돌아온다. 이때 그 자기자신에게 보낸
메시지를 처리하는 함수가 바로 onSelfMsg 함수이다.

TODO: 동작 설명하기 -}
onSelfMsg : Platform.Router msg SelfMsg -> SelfMsg -> State msg -> Task Never (State msg)
onSelfMsg router _ state =
  case state of
    Nothing ->
      Task.succeed state

    Just {taggers} ->
      let
        send tagger =
          Platform.sendToApp router (tagger)
      in
        Task.sequence (List.map send taggers)
          |> Task.andThen (\_ -> Task.succeed state)


{-| TODO: 뭐하는 함수인지 정확히 할아내기

라이브러리 개발자, 유저 둘 다 이 함수를 직접 호출할일이 없다. Elm 런타임이
호출하는 함수인것으로 보인다. `init`, `onEffects`, `onSelfMsg` 함수와는 달리 이
함수는 타입이 강제되지는 않으나, 아래의 꼴대로 정의되지 않으면 모듈이 제대로
작동하지 않는다.

공식문서에 이 함수에 관한 설명이 없어서, 어떻게 쓰이는 함수인지 알수가 없다. -}
subMap : (ty1 -> ty2) -> MySub ty1 -> MySub ty2
subMap fn (MakeMySub tagger) = MakeMySub (fn tagger)
