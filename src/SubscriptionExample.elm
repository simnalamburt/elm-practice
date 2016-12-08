{-| MyEnter 시연용 더미 어플리케이션. -}
import Html exposing (Html, div, h1, text)
import Html.Attributes exposing (style)
import MyKeyboard

--
-- 프로그램 정의
--
main = Html.program
  {
    init = init,
    view = view,
    update = update,
    subscriptions = subscriptions
  }


--
-- 모델 정의.
--
{-| 모델 자료형 정의. Enter 키가 눌린 횟수를 저장한다. -}
type alias Model = Int

{-| 초기 어플리케이션 상태. -}
init : (Model, Cmd Msg)
init = (0, Cmd.none)


--
-- UPDATE
--
{-| Msg 자료형 정의. 유저가 엔터를 칠때마다 `Hit` 메세지가 발생한다. -}
type Msg = Hit


{-| update 함수 정의. Hit 이벤트가 발생할때마다 model이 1씩 늘어난다. -}
update : Msg -> Model -> (Model, Cmd Msg)
update Hit model = (model + 1, Cmd.none)


--
-- SUBSCRIPTIONS
--
{-| TODO: 설명 보충

여러개의 이벤트를 한번에 구독하고싶다면 `Sub.batch`를 사용하면 된다.

http://package.elm-lang.org/packages/elm-lang/core/5.0.0/Platform-Sub
https://www.elm-tutorial.org/en/03-subs-cmds/01-subs.html
-}
subscriptions : Model -> Sub Msg
subscriptions _ = MyKeyboard.downs (\_ -> Hit)


--
-- VIEW
--
view : Model -> Html Msg
view model =
  let
    -- Simple CSS
    containerStyle = style [
      ("text-align", "center"),
      ("padding", "50px")
    ]
    textStyle = style [
      ("margin", "20px"),
      ("color", "gray")
    ]
    countStyle = style [
      ("font-size", "50pt")
    ]
  in
    div [ containerStyle ] [
      div [ countStyle ] [ text (toString model) ],
      h1 [ textStyle ] [ text "아무 키나 입력해주세요" ]
    ]
