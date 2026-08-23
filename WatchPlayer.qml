import QtQuick
import QtMultimedia
import qs.Commons

// In-panel webcast player (Normarchy pattern: MediaPlayer + VideoOutput).
// Source is usually http://127.0.0.1:… from scripts/stream-proxy.py.
Item {
  id: root

  property string streamUrl: ""
  property string originalUrl: ""
  property string featureImage: ""
  property string statusText: ""       // resolving | playing | fallback | error | idle
  property color foreground: Color.foreground
  property color surfaceColor: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
  property string fontFamily: Style.font.family
  property bool muted: false
  property bool active: false

  signal openOriginal()
  signal closeRequested()
  signal muteToggled()
  signal playPauseToggled()

  readonly property bool isFallback: statusText === "fallback" || statusText === "error"
  readonly property bool hasStream: streamUrl.length > 0 && !isFallback

  implicitWidth: Style.space(320)
  implicitHeight: active ? (videoFrame.height + controls.height + Style.space(8)) : 0
  visible: active
  clip: true

  readonly property bool isPlaying: mediaPlayer.playbackState === MediaPlayer.PlayingState

  function play() {
    if (hasStream) mediaPlayer.play()
  }

  function pause() {
    mediaPlayer.pause()
  }

  function stop() {
    mediaPlayer.stop()
    mediaPlayer.source = ""
  }

  function togglePlayPause() {
    if (!hasStream) {
      root.playPauseToggled()
      return
    }
    if (mediaPlayer.playbackState === MediaPlayer.PlayingState)
      mediaPlayer.pause()
    else
      mediaPlayer.play()
    root.playPauseToggled()
  }

  onStreamUrlChanged: {
    if (!active) return
    if (hasStream) {
      mediaPlayer.source = streamUrl
      mediaPlayer.play()
    } else {
      mediaPlayer.stop()
    }
  }

  onActiveChanged: {
    if (!active) {
      // Panel hide / closeWatch: pause then fully stop — no auto-resume.
      pause()
      stop()
    } else if (hasStream) {
      // User re-opened Watch with a stream; play only when they (re)start Watch.
      mediaPlayer.source = streamUrl
      mediaPlayer.play()
    }
  }

  onMutedChanged: {
    audioOutput.muted = muted
  }

  Column {
    id: body
    width: parent.width
    spacing: Style.space(8)

    Rectangle {
      id: videoFrame
      width: parent.width
      height: Style.space(180)
      radius: Math.max(4, Style.cornerRadius)
      color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
      clip: true

      VideoOutput {
        id: videoOut
        anchors.fill: parent
        visible: root.hasStream && mediaPlayer.playbackState !== MediaPlayer.StoppedState
        fillMode: VideoOutput.PreserveAspectFit
      }

      // Poster / fallback thumbnail when X (or resolve) fails
      Image {
        anchors.fill: parent
        source: root.featureImage
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: root.isFallback || root.statusText === "resolving" || !root.hasStream
        opacity: root.isFallback ? 0.85 : 0.45
      }

      Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.35)
        visible: root.statusText === "resolving" || root.isFallback

        Column {
          anchors.centerIn: parent
          spacing: Style.space(6)
          width: parent.width - Style.space(24)

          Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: {
              if (root.statusText === "resolving") return "Resolving stream…"
              if (root.statusText === "error") return "Could not embed this webcast"
              if (root.statusText === "fallback") return "Open original to watch"
              return ""
            }
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: true
            wrapMode: Text.WordWrap
          }

          Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            visible: root.isFallback
            text: "X broadcasts often need the browser; YouTube / HLS embed when yt-dlp can resolve."
            color: root.foreground
            opacity: 0.55
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
        }
      }

      MediaPlayer {
        id: mediaPlayer
        videoOutput: videoOut
        audioOutput: audioOutput
        onErrorOccurred: function(err, detail) {
          // Surface as fallback chrome — caller may also open original.
          root.statusText = "error"
        }
      }

      AudioOutput {
        id: audioOutput
        muted: root.muted
      }
    }

    Row {
      id: controls
      width: parent.width
      spacing: Style.space(8)

      Rectangle {
        width: Style.space(64)
        height: Style.space(28)
        radius: Math.max(3, Style.cornerRadius - 3)
        color: root.foreground
        opacity: root.hasStream ? 1 : 0.35

        Text {
          anchors.centerIn: parent
          text: (mediaPlayer.playbackState === MediaPlayer.PlayingState) ? "PAUSE" : "PLAY"
          color: Color.background
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 1
        }

        MouseArea {
          anchors.fill: parent
          enabled: root.hasStream
          cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: {
            if (mediaPlayer.playbackState === MediaPlayer.PlayingState)
              mediaPlayer.pause()
            else
              mediaPlayer.play()
            root.playPauseToggled()
          }
        }
      }

      Rectangle {
        width: Style.space(64)
        height: Style.space(28)
        radius: Math.max(3, Style.cornerRadius - 3)
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.14)

        Text {
          anchors.centerIn: parent
          text: root.muted ? "UNMUTE" : "MUTE"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 1
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.muted = !root.muted
            root.muteToggled()
          }
        }
      }

      Rectangle {
        width: Style.space(110)
        height: Style.space(28)
        radius: Math.max(3, Style.cornerRadius - 3)
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.14)

        Text {
          anchors.centerIn: parent
          text: "OPEN ORIGINAL"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 1
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.openOriginal()
        }
      }

      Item { width: Math.max(0, parent.width - Style.space(64) * 2 - Style.space(110) - parent.spacing * 3 - closeBtn.width); height: 1 }

      Rectangle {
        id: closeBtn
        width: Style.space(28)
        height: Style.space(28)
        radius: Math.max(3, Style.cornerRadius - 3)
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1)

        Text {
          anchors.centerIn: parent
          text: "×"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.closeRequested()
        }
      }
    }
  }
}
