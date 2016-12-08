{-| MyEnter 시연용 더미 어플리케이션. -}
import Html exposing (Html, div, button, h1, text)
import Html.Attributes exposing (style)
import Html.Events exposing (onClick)
import Maybe exposing (withDefault, map)
import MyEnter

-- TODO: 엔터키 시연용으로 바꾸기

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
{-| 어플리케이션에서 사용할 모델 자료형의 타입.

카운트를 한번도 센적이 없으면 `Nothing`, 카운트를 센적이 있으면 횟수에 따라
`Just 1`, `Just 2`, `Just 3`, ... 으로 증가한다.

Maybe 타입에 관한 설명은 [공식문서] 참고.

[공식문서]: http://package.elm-lang.org/packages/elm-lang/core/5.0.0/Maybe
-}
type alias Model = Maybe Int

{-| 초기 어플리케이션 상태. -}
init : (Model, Cmd Msg)
init = (Nothing, Cmd.none)


--
-- UPDATE
--
{-| Msg 자료형 정의.

유저가 버튼을 누르면 `Count` 메시지가 발생하여 `MyEnter` 모듈에 카운트를
세라는 명령이 전달된다. `MyEnter` 모듈에서 카운트를 완료한 뒤에는
`NewCount` 메시지가 발생한다.

`NewCount` 컨스트럭터는 `Int` 정보를 담을 수 있어, 카운트 결과가 `Int` 안에
담겨진다. -}
type Msg
  -- 버튼을 눌렀을때 발생하는 메시지
  = Count
  -- MyEnter가 숫자를 세었을때 발생되는 메시지
  | NewCount Int


{-| update 함수 정의. 평범하게 생겼지만, 눈여겨봐야할곳은 아래의 부분이다.

    ...
    Count -> (model, MyEnter.count NewCount)
    ...

MyEnter.count 함수에 `NewCount` 컨스트럭터를 넘기고있다. NewCount 컨스트럭터는
Msg 타입의 생성자이기도 하지만, 그냥 하나의 함수처럼도 쓸 수 있다.

    NewCount : Int -> Msg

`1`이라는 값을 `NewCount` 함수에 넘기면 `NewCount 1`이라는 `Msg` 타입이
발생하는것.

우리는 숫자를 셀때마다 0, 1, 2, ... 의 정수 대신에 NewCount 0, NewCount 1,
NewCount 2, ... 의 `Msg` 타입을 발생시켜야 한다. 이에 대한 자세한 설명은
`MyEnter` 모듈의 설명 참고. -}
update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Count -> (model, MyEnter.count NewCount)
    NewCount number -> (Just number, Cmd.none)


--
-- SUBSCRIPTIONS
--
{-| 본 예제에선 subscription을 쓰지 않기때문에, 빈 함수로 둔다.  -}
subscriptions : Model -> Sub Msg
subscriptions model = Sub.none


--
-- VIEW
--
view : Model -> Html Msg
view model =
  let
    -- 버튼 안에 들어갈 글자
    content : Html Msg
    content =
      map toString model
      |> withDefault "click" -- model이 `Nothing`이면 이 글자가 표시됨
      |> text

    -- Simple CSS
    containerStyle = style [
      ("text-align", "center")
    ]

    buttonStyle = style [
      ("background", "#5a5a5a"),
      ("border", "none"),
      ("border-radius", "100%"),
      ("width", "200px"),
      ("height", "200px"),
      ("margin", "50px"),
      ("padding", "0"),
      ("font-size", "50pt"),
      ("color", "white"),
      ("display", "inline-block"),
      ("outline", "none")
    ]
  in
    div [ containerStyle ] [
      button [ onClick Count, buttonStyle ] [ content ]
    ]
