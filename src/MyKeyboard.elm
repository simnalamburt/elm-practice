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


-- TODO: 유닛타입 정리
type MySub msg = MakeMySub msg


subMap : (a -> b) -> MySub a -> MySub b
subMap func (MakeMySub tagger) = MakeMySub (func tagger)



-- EFFECT MANAGER STATE


type alias State msg =
  Dict.Dict String (Watcher msg)


-- TODO: 유닛타입 저일
type alias Watcher msg =
  { taggers : List msg
  , pid : Process.Id
  }



-- CATEGORIZE SUBSCRIPTIONS


-- TODO: 유닛타입 저일
type alias SubDict msg =
  Dict.Dict String (List msg)


categorize : List (MySub msg) -> SubDict msg
categorize subs =
  categorizeHelp subs Dict.empty


categorizeHelp : List (MySub msg) -> SubDict msg -> SubDict msg
categorizeHelp subs subDict =
  case subs of
    [] ->
      subDict

    -- TODO: 정리하기
    mySub :: rest ->
      let
        (MakeMySub tagger) = mySub
        newDict = Dict.update "keydown" (categorizeHelpHelp tagger) subDict
      in
      categorizeHelp rest newDict


categorizeHelpHelp : a -> Maybe (List a) -> Maybe (List a)
categorizeHelpHelp value maybeValues =
  case maybeValues of
    Nothing ->
      Just [value]

    Just values ->
      Just (value :: values)



-- EFFECT MANAGER


init : Task Never (State msg)
init =
  Task.succeed Dict.empty


-- TODO: 없애기
category : String
category = "keydown"


type alias Msg =
  { category : String
  }


(&>) task1 task2 =
  Task.andThen (\_ -> task2) task1


onEffects : Platform.Router msg Msg -> List (MySub msg) -> State msg -> Task Never (State msg)
onEffects router newSubs oldState =
  let

    leftStep category {pid} task =
      Process.kill pid &> task

    bothStep category {pid} taggers task =
      Task.map (Dict.insert category (Watcher taggers pid)) task

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
        )
  in
    Dict.merge
      leftStep
      bothStep
      rightStep
      oldState
      (categorize newSubs)
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

