import Html exposing (Html, div, button, h1, text)
import Html.Events exposing (onClick)
import Maybe exposing (withDefault, map)
import MyCounter

main = Html.program
  {
    init = init,
    view = view,
    update = update,
    subscriptions = subscriptions
  }

-- MODEL
type alias Model = Maybe Int

init : (Model, Cmd Msg)
init = (Nothing, Cmd.none)

-- UPDATE
type Msg = Count
         | NewCount Int

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Count -> (model, MyCounter.count NewCount)
    NewCount number -> (Just number, Cmd.none)

-- SUBSCRIPTIONS
subscriptions : Model -> Sub Msg
subscriptions model = Sub.none

-- VIEW
view : Model -> Html Msg
view model =
  div [] [
    button [ onClick Count ] [ text "Count" ],
    h1 [] [ text (withDefault "버튼을 눌러보세요!" (map toString model)) ]
  ]
