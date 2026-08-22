import QtQuick

Canvas {
  id: root

  property color iconColor: "#f05ac9"
  property real strokeScale: 0.105

  implicitWidth: 18
  implicitHeight: 18

  onIconColorChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()

  onPaint: {
    var ctx = getContext("2d")
    ctx.reset()
    var scale = Math.min(width, height)
    var ox = (width - scale) / 2
    var oy = (height - scale) / 2
    function px(value) { return value * scale / 64 }

    ctx.strokeStyle = iconColor
    ctx.lineWidth = Math.max(1.5, scale * strokeScale)
    ctx.lineCap = "square"
    ctx.lineJoin = "miter"

    ctx.beginPath()
    ctx.moveTo(ox + px(49), oy + px(12))
    ctx.lineTo(ox + px(21), oy + px(12))
    ctx.lineTo(ox + px(14), oy + px(20))
    ctx.lineTo(ox + px(21), oy + px(28))
    ctx.lineTo(ox + px(43), oy + px(28))
    ctx.lineTo(ox + px(50), oy + px(36))
    ctx.lineTo(ox + px(43), oy + px(44))
    ctx.lineTo(ox + px(15), oy + px(44))
    ctx.stroke()

    ctx.beginPath()
    ctx.moveTo(ox + px(32), oy + px(43))
    ctx.lineTo(ox + px(32), oy + px(56))
    ctx.moveTo(ox + px(24), oy + px(48))
    ctx.lineTo(ox + px(32), oy + px(56))
    ctx.lineTo(ox + px(40), oy + px(48))
    ctx.stroke()
  }
}
