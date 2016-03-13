module Draft where
import User exposing (Model)
import Time exposing (Time)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode as Json

type alias Model =
  { content : String
  , author : User.Model
  , shift : Bool
  , rows : Int
  }

type alias ID = String

init : User.Model -> Model
init author =
  { content = ""
  , author = author
  , shift = False
  , rows = 1
  }

type Action
  = Send
  | NewLine
  | TabPress
  | Content String
  | SetShift Bool
  | Author User.Model

update : Action -> Time -> Model -> Model
update action time model =
  case action of
    Send ->
      init model.author
    NewLine ->
      { model | content = model.content ++ "\r\n", rows = model.rows + 1 }
    TabPress ->
      model
    Content content ->
      { model | content = content }
    SetShift bool ->
      { model | shift = bool }
    Author author ->
      { model | author = author }


view : Signal.Address Action -> Model -> Html
view address model =
    div []
        [ textarea
              [ placeholder "Need some help?"
              , value model.content
              , onKeydown address model
              , on "input" targetValue (Signal.message address << Content)
              , autofocus True
              , textareaStyle
              , rows model.rows
              , cols 10
              ]
              []
        ]

textareaStyle : Attribute
textareaStyle =
    style
        [ ("width", "100%")
        , ("padding", "10px 0")
        , ("font-size", "1em")
        , ("resize", "none")
        , ("overflow", "hidden")
        ]

type KeyDown
  = Enter
  | ShiftEnter
  | Tab

onKeydown : Signal.Address Action -> Model -> Attribute
onKeydown address model =
  let
      options = {preventDefault = True, stopPropagation = False}
      dec =
        (Json.customDecoder keyCode (\k ->
          if k == 13 && model.shift then
            Ok ShiftEnter
          else if k == 13 then
            Ok Enter
          else if k == 9 then
            Ok Tab
          else Err "not handling that key"))
  in
      onWithOptions "keydown" options dec (\k ->
            Signal.message address <|
              case k of
                  Enter -> Send
                  ShiftEnter -> NewLine
                  Tab -> TabPress)