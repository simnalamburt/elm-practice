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
type alias State msg = Dict.Dict String (Watcher msg)

init : Task Never (State msg)
init = Task.succeed Dict.empty


type alias Msg =
  { category : String
  }


(&>) task1 task2 =
  Task.andThen (\_ -> task2) task1


onEffects : Platform.Router msg Msg -> List (MySub msg) -> State msg -> Task Never (State msg)
onEffects router newSubs oldState =
  let
    -- TODO: 안쓰는 카테고리 다 삭제

    -- TODO: pid는 왜나올까
    leftStep : String -> Watcher msg -> Task Never (State msg) -> Task Never (State msg)
    leftStep category {pid} task =
      Process.kill pid &> task

    bothStep : String -> Watcher msg -> List msg -> Task Never (State msg) -> Task Never (State msg)
    bothStep category {pid} taggers task =
      Task.map (Dict.insert category (Watcher taggers pid)) task

    rightStep : String -> List msg -> Task Never (State msg) -> Task Never (State msg)
    rightStep category taggers task =
      let
        -- 별 의미없이 있는 함수. 원래는 onDocument 콜백의 결과로 주어지는
        -- 키코드를 파싱하는데 쓰는 함수지만, 본 예제에선 키코드 값을 버리므로
        -- 의미가 없다.
        -- Reference: http://package.elm-lang.org/packages/elm-lang/core/5.0.0/Json-Decode
        keyCode : Json.Decoder ()
        keyCode = Json.succeed ()

        -- onDocument 함수에 넣을 콜백함수
        callBack : () -> Task Never ()
        callBack () = Platform.sendToSelf router (Msg category)

        -- onDocument 호출로 생성한 프로미스
        -- Reference: http://package.elm-lang.org/packages/elm-lang/dom/1.1.1/Dom-LowLevel#onDocument
        promise : Task Never Never
        promise = Dom.onDocument "keydown" keyCode callBack

      in
        task
        |> Task.andThen (
          \state -> Process.spawn promise
          |> Task.andThen (\pid -> Task.succeed (Dict.insert category (Watcher taggers pid) state))
          -- TODO: Watcher는 멀까
        )

    -- TODO: 동작 이해해서 정리하기
  in
    Dict.merge
      leftStep
      bothStep
      rightStep
      oldState
      (Dict.insert "keydown" (categorize newSubs) Dict.empty) -- TODO: 정리
      (Task.succeed Dict.empty)


onSelfMsg : Platform.Router msg Msg -> Msg -> State msg -> Task Never (State msg)
onSelfMsg router {category} state =
  case Dict.get category state of
    Nothing ->
      Task.succeed state

    Just {taggers} ->
      let
        send tagger =
          Platform.sendToApp router (tagger)
      in
        Task.sequence (List.map send taggers)
          |> Task.andThen (\_ -> Task.succeed state)

