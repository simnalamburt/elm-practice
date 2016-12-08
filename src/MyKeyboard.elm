effect module MyKeyboard where { subscription = MySub } exposing (downs)

{-|
TODO: 설명 보충
-}

import Dict
import Dom.LowLevel as Dom
import Json.Decode as Json
import Process
import Task exposing (Task)




{-| Subscribe to get codes whenever a key goes down.
-}
downs : msg -> Sub msg
downs tagger =
  subscription (MakeMySub tagger)



-- SUBSCRIPTIONS
type MySub msg = MakeMySub msg


subMap : (a -> b) -> MySub a -> MySub b
subMap func (MakeMySub tagger) = MakeMySub (func tagger)


type alias Watcher msg =
  { taggers : List msg
  , pid : Process.Id
  }


-- CATEGORIZE SUBSCRIPTIONS
categorize : List (MySub msg) -> List msg
categorize subs = List.map (\(MakeMySub msg) -> msg) subs


-- EFFECT MANAGER
type alias State msg = Maybe (Watcher msg)

init : Task Never (State msg)
init = Task.succeed Nothing


type alias SelfMsg = ()


(&>) task1 task2 =
  Task.andThen (\_ -> task2) task1

-- TODO: 삭제
key : String
key = "keydown"


-- TODO: 이벤트핸들러 붙였다 떼었다 하면서 테스트하기
onEffects : Platform.Router msg SelfMsg -> List (MySub msg) -> State msg -> Task Never (State msg)
onEffects router newSubs oldState =
  let
    bothStep : Watcher msg -> List msg -> Task Never (State msg) -> Task Never (State msg)
    bothStep {pid} taggers task =
      -- TODO: 이상해
      Task.map (\task -> Just (Watcher taggers pid)) task

    rightStep : List msg -> Task Never (State msg) -> Task Never (State msg)
    rightStep taggers task =
      let
        -- 별 의미없이 있는 함수. 원래는 onDocument 콜백의 결과로 주어지는
        -- 키코드를 파싱하는데 쓰는 함수지만, 본 예제에선 키코드 값을 버리므로
        -- 의미가 없다.
        -- Reference: http://package.elm-lang.org/packages/elm-lang/core/5.0.0/Json-Decode
        keyCode : Json.Decoder ()
        keyCode = Json.succeed ()

        -- onDocument 함수에 넣을 콜백함수
        callBack : () -> Task Never ()
        callBack () = Platform.sendToSelf router ()

        -- onDocument 호출로 생성한 프로미스
        -- Reference: http://package.elm-lang.org/packages/elm-lang/dom/1.1.1/Dom-LowLevel#onDocument
        promise : Task Never Never
        promise = Dom.onDocument key keyCode callBack

      in
        task
        |> Task.andThen (
          \state -> Process.spawn promise
          |> Task.andThen (\pid -> Task.succeed (Just (Watcher taggers pid)))
        )

    -- TODO: 이름짓기
    right : List msg
    right = categorize newSubs

    merged : Task Never (State msg)
    merged = case oldState of
      Nothing   -> rightStep right init
      Just left -> bothStep left right init
  in
    merged


onSelfMsg : Platform.Router msg SelfMsg -> SelfMsg -> State msg -> Task Never (State msg)
onSelfMsg router () state =
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
