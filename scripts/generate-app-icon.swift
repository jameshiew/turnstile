import AppKit

let size = 1024
let outputURL = URL(filePath: CommandLine.arguments[1])
let representation = NSBitmapImageRep(
  bitmapDataPlanes: nil,
  pixelsWide: size,
  pixelsHigh: size,
  bitsPerSample: 8,
  samplesPerPixel: 4,
  hasAlpha: true,
  isPlanar: false,
  colorSpaceName: .deviceRGB,
  bytesPerRow: 0,
  bitsPerPixel: 0
)!

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: representation)
NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: size, height: size).fill()

let tile = NSBezierPath(
  roundedRect: NSRect(x: 72, y: 72, width: 880, height: 880),
  xRadius: 196,
  yRadius: 196
)
let gradientStart = NSColor(red: 0.15, green: 0.34, blue: 0.98, alpha: 1)
let gradientEnd = NSColor(red: 0.35, green: 0.16, blue: 0.82, alpha: 1)
NSGradient(colors: [gradientStart, gradientEnd])!.draw(in: tile, angle: -48)

let highlight = NSBezierPath(
  ovalIn: NSRect(x: 110, y: 500, width: 804, height: 500)
)
NSGraphicsContext.saveGraphicsState()
tile.addClip()
NSColor.white.withAlphaComponent(0.1).setFill()
highlight.fill()
NSGraphicsContext.restoreGraphicsState()

func strokedPath(from start: NSPoint, to end: NSPoint, control: NSPoint? = nil) {
  let path = NSBezierPath()
  path.move(to: start)
  if let control {
    path.curve(
      to: end,
      controlPoint1: control,
      controlPoint2: NSPoint(x: control.x + 70, y: end.y)
    )
  } else {
    path.line(to: end)
  }
  path.lineWidth = 58
  path.lineCapStyle = .round
  NSColor.white.setStroke()
  path.stroke()
}

strokedPath(from: NSPoint(x: 230, y: 512), to: NSPoint(x: 480, y: 512))
strokedPath(
  from: NSPoint(x: 490, y: 512),
  to: NSPoint(x: 780, y: 730),
  control: NSPoint(x: 585, y: 512)
)
strokedPath(
  from: NSPoint(x: 490, y: 512),
  to: NSPoint(x: 780, y: 294),
  control: NSPoint(x: 585, y: 512)
)

NSColor.white.setFill()
NSBezierPath(ovalIn: NSRect(x: 432, y: 464, width: 96, height: 96)).fill()

for endpoint in [NSPoint(x: 780, y: 730), NSPoint(x: 780, y: 294)] {
  NSBezierPath(
    ovalIn: NSRect(x: endpoint.x - 38, y: endpoint.y - 38, width: 76, height: 76)
  ).fill()
}

NSGraphicsContext.restoreGraphicsState()
let data = representation.representation(using: .png, properties: [:])!
try data.write(to: outputURL, options: .atomic)
