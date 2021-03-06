module Main (..) where

import Chat
import Dict exposing (Dict)
import User
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Keyboard
import Task
import Effects exposing (Effects, Never)
import Signal exposing (Mailbox)
import Time exposing (Time, second, since)
import TimeApp
import Message
import Draft
import User exposing (anonymous)
import Participant exposing (Participant, Status, defaultStatus, statusToString, statusFromString)


type alias Model =
  { me : Participant
  , chat : Chat.Model
  , shift : Bool
  , participants : List Participant
  , users : Dict String User.Model
  , scrollToBottom : Bool
  }


init : User.Model -> Chat.Model -> Model
init user chat =
  { me = Participant.init user
  , chat = chat
  , shift = False
  , participants = []
  , users = Dict.fromList [ ( "anonymous", User.anonymous ) ]
  , scrollToBottom = False
  }


initialModel : Model
initialModel =
  let
    users =
      (Dict.fromList [ ( "anonymous", User.anonymous ) ])

    chat =
      Chat.init "123456" User.anonymous users

    model =
      init User.anonymous chat
  in
    model


type Action
  = Chat Chat.Action
  | ChangeUser User.Handle
  | SetShift Bool
  | Users (List ( User.Handle, User.Model ))
  | Messages (List Message.Model)
  | IsTyping Bool
  | Participants (List Participant)
  | ScrollToBottom Bool
  | ScrollToBottomOnRender Time


update : Action -> Time -> Model -> ( Model, Effects Action )
update action time model =
  case action of
    Chat act ->
      ( { model | chat = Chat.update act time model.chat }
      , Effects.none
      )

    ChangeUser handle ->
      let
        chat =
          model.chat

        user =
          User.getUserOrAnon handle model.users

        updatedChat =
          { chat | viewer = user }
      in
        ( { model
            | me = Participant.init user
            , chat = Chat.update (Chat.ChangeViewer user) time model.chat
          }
        , Effects.none
        )

    SetShift bool ->
      ( { model | shift = bool, chat = Chat.update (Chat.SetShift bool) time model.chat }
      , Effects.none
      )

    Users users ->
      ( { model
          | chat = Chat.update (Chat.UpdateAllUsers (Dict.fromList users)) time model.chat
          , users = Dict.fromList users
        }
      , Effects.none
      )

    Messages messages ->
      ( { model | chat = Chat.update (Chat.UpdateMessages messages) time model.chat }
      , Effects.tick ScrollToBottomOnRender
      )

    IsTyping bool ->
      ( { model
          | me =
              if bool then
                Participant.initWithStatus model.me.profile (statusToString Participant.Typing)
              else
                Participant.init model.me.profile
        }
      , Effects.none
      )

    Participants participants ->
      ( { model | participants = participants }
      , Effects.none
      )

    ScrollToBottom bool ->
      ( { model | scrollToBottom = bool }
      , Effects.none
      )

    ScrollToBottomOnRender clockTime ->
      ( { model | scrollToBottom = True }
      , Effects.none
      )


view : Signal.Address Action -> Model -> Html
view address model =
  div
    []
    [ viewElmLink
    , viewBackground address model
    ]


viewBackground : Signal.Address Action -> Model -> Html
viewBackground address model =
  div
    [ backgroundStyle ]
    [ viewAppContainer address model
    ]


viewElmLink : Html
viewElmLink =
  a
    [ href "http://elm-lang.org/", value "_blank", elmLinkStyle ]
    [ img [ style [ ( "width", "24px" ) ], src "http://elm-lang.org/assets/logo.svg" ] [] ]


viewAppContainer : Signal.Address Action -> Model -> Html
viewAppContainer address model =
  if User.isAnonymous model.me.profile then
    div
      [ containerStyle ]
      [ viewChat address model True
      , viewLogin address model
      ]
  else
    div
      [ containerStyle ]
      [ viewChatHeader model
      , viewChat address model False
      ]


viewChat : Signal.Address Action -> Model -> Bool -> Html
viewChat address model readOnly =
  let
    chat =
      if readOnly then
        Chat.viewReadOnly (Signal.forwardTo address Chat) model.chat
      else
        Chat.view (Signal.forwardTo address Chat) model.chat
  in
    div
      [ chatStyle ]
      [ chat ]


viewChatHeader : Model -> Html
viewChatHeader model =
  div
    [ chatHeaderStyle ]
    [ viewParticipantList model.participants ]


viewParticipantList : List Participant -> Html
viewParticipantList participants =
  div
    [ participantListStyle ]
    (List.map Participant.view participants)


viewLogin : Signal.Address Action -> Model -> Html
viewLogin address model =
  div
    []
    (p [] [ text "Login as: " ] :: (viewLoginButtons address model))


viewLoginButtons : Signal.Address Action -> Model -> List Html
viewLoginButtons address model =
  Dict.values model.users
    |> List.map (\user -> viewUserButton address user)


viewUserButton : Signal.Address Action -> User.Model -> Html
viewUserButton address user =
  button [ onClick address (ChangeUser user.handle) ] [ text user.name ]


elmLinkStyle : Attribute
elmLinkStyle =
  style
    [ ( "position", "absolute" )
    , ( "left", "1em" )
    , ( "margin-top", "1em" )
    ]


backgroundStyle : Attribute
backgroundStyle =
  style
    [ ( "background", "#60B5CC" )
    , ( "height", "100vh" )
    , ( "-webkit-overflow-scrolling", "touch" )
    , ( "overflow", "scroll" )
    , ( "padding", "40px 0" )
    , ( "color", "white" )
    ]


containerStyle : Attribute
containerStyle =
  style
    [ ( "margin", "0 auto" )
    , ( "width", "75%" )
    , ( "background", "#F2F5F8" )
    , ( "border-radius", "5px" )
    , ( "border", "2px solid #293c4b" )
    ]


chatHeaderStyle : Attribute
chatHeaderStyle =
  style
    [ ( "padding", "20px" )
    , ( "border-bottom", "2px solid white" )
    ]


participantListStyle : Attribute
participantListStyle =
  style
    [ ( "display", "flex" )
    , ( "align-items", "center" )
    ]


chatStyle : Attribute
chatStyle =
  style
    [ ( "border-top-right-radius", "5px" )
    , ( "border-bottom-right-radius", "5px" )
    ]


app : TimeApp.App Model
app =
  TimeApp.start
    { init = ( initialModel, Effects.none )
    , update = update
    , view = view
    , inputs =
        [ Signal.map Messages messages
        , Signal.map Participants participants
        , Signal.map Users users
        , Signal.map IsTyping (second `since` Keyboard.presses)
        , Signal.map SetShift Keyboard.shift
        , Signal.map ScrollToBottom scrollToBottom
        ]
    }


main : Signal Html
main =
  app.html


port tasks : Signal (Task.Task Never ())
port tasks =
  app.tasks


port messages : Signal (List Message.Model)
port participants : Signal (List Participant)
port users : Signal (List ( User.Handle, User.Model ))
port scrollToBottom : Signal Bool
port me : Signal Participant
port me =
  Signal.map (\model -> model.me) app.model
    |> Signal.dropRepeats


port drafts : Signal (List Draft.Model)
port drafts =
  Signal.map (\m -> m.chat.outbox) app.model
    |> Signal.dropRepeats


port autoScroll : Signal Bool
port autoScroll =
  Signal.map (\model -> model.scrollToBottom) app.model
    |> Signal.dropRepeats
