import SpriteKit
import UIKit
import AVFoundation

let gridSize = 8
let cellSize: CGFloat = 50
var gridOrigin: CGPoint = .zero


enum ProspectiveHighlightEffectType {
    case lineClear        // Normal hat temizleme: Aktif bloğun rengini alır
    case bombArea         // Bomba alanı: Bombanın kendi rengini alır
    case rainbowTarget    // Gökkuşağı hedefi: Özel efekt, orijinal renk korunur
}
enum BlockType {
    case normal
    case bomb
    case rainbow
}

struct GridCoordinate: Hashable {
    let row: Int
    let col: Int
}

struct BlockShape {
    let cells: [(Int, Int)]
    let color: SKColor
    let type: BlockType
}

class BlockNode: SKNode {
    let blockShape: BlockShape
    init(blockShape: BlockShape) {
        self.blockShape = blockShape
        super.init()
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class GameScene: SKScene {
    private enum SoundEvent {
        case place, lineClear, combo, bomb, rainbow
    }
    let pointsPerBlockFromSpecial: Int = 25
    var nextBlocks: [SKNode] = []
    var selectedNode: SKNode?
    var lastValidPosition: CGPoint?
    var isDragging = false
    var gridNodes: [[SKShapeNode]] = []
    var gridState: [[Int]] = []
    var gridSpriteMap: [[SKShapeNode?]] = []
    var blockOffset: CGPoint = .zero
    var scoreLabel: SKLabelNode!
    var score = 0
    var rotateUsed = false
    var rotateButton: SKSpriteNode!
    var comboCount = 0
    var audioPlayer: AVAudioPlayer?
    private let previewBarHeight: CGFloat = 110
    let previewContainer = SKNode()
    var topPanel: SKShapeNode?
    private var bottomPanel: SKShapeNode?
    private var gameOverFillerSprites: [SKShapeNode] = []
    private var isProcessingPlacement = false //  KİLİT DEĞİŞKENİ
    private var scoreForNextLevel = 1500 // Bir sonraki seviye için gereken puan
    private var currentLevel = 1
    private var levelLabel: SKLabelNode! // Seviyeyi gösterecek etiket
    private var isSettingsPanelDisplayed = false
    
    deinit {
            print("✅ GameScene hafızadan başarıyla silindi. (Deallocated)")
        }
    
    // GameScene sınıfı içinde, en üste yakın bir yere:
    enum HighlightedNodeType {
        case gridCell
        case existingBlockPart
    }

    // prospectiveHighlightTargets değişken tanımınız:
    // private var prospectiveHighlightTargets: [(node: SKShapeNode, originalFillColor: SKColor, originalStrokeColor: SKColor, originalLineWidth: CGFloat, originalAlpha: CGFloat)] = []
    // Şöyle güncellenmeli:
    private var prospectiveHighlightTargets: [
        (
            node: SKShapeNode,
            type: HighlightedNodeType,
            originalFillColor: SKColor,    // gridCell için hücrenin orijinal rengi, existingBlockPart için ana dolgu rengi
            originalStrokeColor: SKColor, // gridCell için hücrenin orijinal stroke'u, existingBlockPart için ana stroke'u
            originalLineWidth: CGFloat,   // İkisi için de orijinal lineWidth
            originalAlpha: CGFloat        // İkisi için de orijinal alpha
        )
    ] = []
    
    
    
    func showSettingsMenu() {
        // Arka yarı saydam overlay
        let overlay = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height))
        overlay.position = CGPoint(x: size.width/2, y: size.height/2)
        overlay.fillColor = SKColor.black.withAlphaComponent(0.57)
        overlay.zPosition = 1000
        overlay.name = "settingsOverlay"
        addChild(overlay)
        
        // --- DEĞİŞİKLİK 1: Panel Yüksekliğini Artır ---
        // Yeni butonlara yer açmak için panelin yüksekliğini 170'den 260'a çıkardık.
        let panel = SKShapeNode(rectOf: CGSize(width: 320, height: 260), cornerRadius: 22)
        panel.position = CGPoint(x: size.width/2, y: size.height/2)
        panel.fillColor = SKColor(red: 0.13, green: 0.14, blue: 0.2, alpha: 1.0)
        panel.strokeColor = SKColor.cyan
        panel.lineWidth = 3
        panel.zPosition = 1100
        panel.name = "settingsPanel"
        addChild(panel)
        
        // --- DEĞİŞİKLİK 2: Mevcut Elemanları Yeniden Konumlandır ---
        // Başlık
        let title = SKLabelNode(text: "Ayarlar")
        title.fontName = "AvenirNext-Bold"
        title.fontSize = 28
        title.fontColor = .cyan
        title.position = CGPoint(x: 0, y: 100) // Y-pozisyonu güncellendi
        title.zPosition = 1111
        panel.addChild(title)
        
        // Ses Ayarı
        let soundLabel = SKLabelNode(text: "Ses Efekti")
        soundLabel.fontName = "AvenirNext-Bold"; soundLabel.fontSize = 19; soundLabel.fontColor = .white; soundLabel.horizontalAlignmentMode = .left
        soundLabel.position = CGPoint(x: -120, y: 50) // Y-pozisyonu güncellendi
        panel.addChild(soundLabel)
        let soundSwitch = SKLabelNode(text: Settings.isSoundEnabled ? "AÇIK" : "KAPALI")
        soundSwitch.name = "soundSwitch"; soundSwitch.fontName = "AvenirNext-Bold"; soundSwitch.fontSize = 19; soundSwitch.fontColor = Settings.isSoundEnabled ? .systemGreen : .systemRed
        soundSwitch.position = CGPoint(x: 90, y: 50) // Y-pozisyonu güncellendi
        panel.addChild(soundSwitch)
        
        // Titreşim Ayarı
        let hapticLabel = SKLabelNode(text: "Titreşim")
        hapticLabel.fontName = "AvenirNext-Bold"; hapticLabel.fontSize = 19; hapticLabel.fontColor = .white; hapticLabel.horizontalAlignmentMode = .left
        hapticLabel.position = CGPoint(x: -120, y: 10) // Y-pozisyonu güncellendi
        panel.addChild(hapticLabel)
        let hapticSwitch = SKLabelNode(text: Settings.isHapticEnabled ? "AÇIK" : "KAPALI")
        hapticSwitch.name = "hapticSwitch"; hapticSwitch.fontName = "AvenirNext-Bold"; hapticSwitch.fontSize = 19; hapticSwitch.fontColor = Settings.isHapticEnabled ? .systemGreen : .systemRed
        hapticSwitch.position = CGPoint(x: 90, y: 10) // Y-pozisyonu güncellendi
        panel.addChild(hapticSwitch)
        
        // --- DEĞİŞİKLİK 3: EKSİK BUTONLARI EKLE ---
        // touchesBegan fonksiyonunuzun beklediği isimlerle butonları oluşturuyoruz.
        
        // Yeniden Başlat Butonu
        let restartButton = SKLabelNode(text: "Yeniden Başlat")
        restartButton.name = "restartSettingsButton" // Dokunma mantığı bu ismi arıyor
        restartButton.fontName = "AvenirNext-Bold"
        restartButton.fontSize = 18
        restartButton.fontColor = .systemOrange // Farklı bir renk
        restartButton.position = CGPoint(x: 0, y: -40)
        panel.addChild(restartButton)
        
        // Ana Menü Butonu
        let menuButton = SKLabelNode(text: "Ana Menü")
        menuButton.name = "menuSettingsButton" // Dokunma mantığı bu ismi arıyor
        menuButton.fontName = "AvenirNext-Bold"
        menuButton.fontSize = 18
        menuButton.fontColor = .systemRed // Farklı bir renk
        menuButton.position = CGPoint(x: 0, y: -80)
        panel.addChild(menuButton)
        
        // Kapat Butonu
        let closeButton = SKLabelNode(text: "Kapat")
        closeButton.name = "closeSettings"
        closeButton.fontName = "AvenirNext-Bold"; closeButton.fontSize = 18; closeButton.fontColor = .systemIndigo
        closeButton.position = CGPoint(x: 0, y: -110) // Y-pozisyonu güncellendi
        closeButton.zPosition = 1112
        panel.addChild(closeButton)
    }

    
    
    // resetProspectiveHighlights fonksiyonunuz:
    func resetProspectiveHighlights() {
        for target in prospectiveHighlightTargets {
            target.node.removeAction(forKey: "prospectiveClearPulse")
            target.node.alpha = target.originalAlpha
            // target.node.lineWidth = target.originalLineWidth // Bu satır kalsın, genel lineWidth'ı geri yükler.

            switch target.type {
            case .existingBlockPart:
                // Blok parçasının görünümünü orijinal ana dolgu rengine göre tamamen yeniden oluştur
                updateBlockPartAppearance(spriteNode: target.node, newBaseColor: target.originalFillColor)
                // updateBlockPartAppearance ana sprite'ın stroke'unu ve lineWidth'ını da yönettiği için
                // target.originalStrokeColor ve target.originalLineWidth'ı burada tekrar set etmeye gerek yok,
                // ancak addBevelEffect'teki lineWidth (0.5) sabit kalmalı.
                // Eğer vurgu sırasında lineWidth değişiyorsa (aşağıdaki applyProspectiveClearHighlight'ta olduğu gibi),
                // o zaman burada da orijinaline dönmeli.
                 target.node.lineWidth = target.originalLineWidth // Bu satırın burada olması daha doğru.
            case .gridCell:
                target.node.fillColor = target.originalFillColor
                target.node.strokeColor = target.originalStrokeColor
                target.node.lineWidth = target.originalLineWidth // Bu satır da burada olmalı.
            }
        }
        prospectiveHighlightTargets.removeAll()
    }
    // GameScene sınıfı içinde:
    // GameScene sınıfı içinde:
    func updateScoreLabel() {
            // scoreLabel'ın nil olup olmadığını kontrol edin
            guard scoreLabel != nil else {
                // Bu durum normalde olmamalı, ama bir güvenlik önlemi
                print("Hata: scoreLabel tanımlanmamış.")
                return
            }
            scoreLabel.text = "Skor: \(score)"
            
            let currentHighScore = UserDefaults.standard.integer(forKey: "HighScore")
            if score > currentHighScore {
                UserDefaults.standard.set(score, forKey: "HighScore")
                // highScoreLabel'a erişim (topPanel'in çocuğu olduğunu varsayarak)
                if let panel = topPanel, let highScoreLabel = panel.childNode(withName: "highScoreLabel") as? SKLabelNode {
                    highScoreLabel.text = "En Yüksek: \(score)"
                } else if let highScoreLabel = childNode(withName: "highScoreLabel") as? SKLabelNode {
                    // Fallback: Eğer topPanel'in çocuğu değilse, direkt sahneden ara
                    // Bu, highScoreLabel'ın nerede tanımlandığına bağlı olarak ayarlanmalı.
                    highScoreLabel.text = "En Yüksek: \(score)"
                }
            }
        }
    
    // GameScene sınıfı içinde:
    // GameScene sınıfı içinde (Mevcut applyProspectiveClearHighlight fonksiyonunuzun yerine bunu koyun):
    func applyProspectiveClearHighlight(forPlacing placedBlockPositionsTuples: [(row: Int, col: Int)], activeBlockNode: BlockNode?) {
            guard let currentBlockNode = activeBlockNode, !placedBlockPositionsTuples.isEmpty else {
                return
            }

            let blockType = currentBlockNode.blockShape.type
            let activeBlockOriginalColor = currentBlockNode.blockShape.color // Aktif bloğun (bomba, gökkuşağı veya normal) kendi rengi

            switch blockType {
            case .normal:
                // --- Normal Bloklar İçin Hat Temizleme Vurgusu ---
                let placedBlockCoords = placedBlockPositionsTuples.map { GridCoordinate(row: $0.row, col: $0.col) }
                var tempGridForLineCheck = gridState
                for pos in placedBlockCoords {
                    if pos.row >= 0 && pos.row < gridSize && pos.col >= 0 && pos.col < gridSize {
                        tempGridForLineCheck[pos.row][pos.col] = 1
                    }
                }
                var fullRows: [Int] = [], fullCols: [Int] = []
                for r in 0..<gridSize { if tempGridForLineCheck[r].allSatisfy({ $0 == 1 }) { fullRows.append(r) } }
                for c in 0..<gridSize { if (0..<gridSize).allSatisfy({ r in tempGridForLineCheck[r][c] == 1 }) { fullCols.append(c) } }

                if !fullRows.isEmpty || !fullCols.isEmpty {
                    var lineClearCells: Set<GridCoordinate> = []
                    for r in fullRows { for c in 0..<gridSize { lineClearCells.insert(GridCoordinate(row: r, col: c)) } }
                    for c in fullCols { for r in 0..<gridSize { lineClearCells.insert(GridCoordinate(row: r, col: c)) } }
                    
                    // Temizlenecek hattaki hücreler, aktif normal bloğun rengini alır.
                    highlightCellSet(lineClearCells,
                                     baseColor: activeBlockOriginalColor.withAlphaComponent(1.0),
                                     effectType: .lineClear)
                }

            case .bomb:
                // --- Bomba Bloğu İçin 3x3 Alan Vurgusu ---
                guard let landingPosTuple = placedBlockPositionsTuples.first else { return } // Bombanın merkez hücresi
                let landingPos = GridCoordinate(row: landingPosTuple.row, col: landingPosTuple.col)
                
                var cellsInBlastRadius: Set<GridCoordinate> = []
                for r_offset in -1...1 {
                    for c_offset in -1...1 {
                        let r = landingPos.row + r_offset
                        let c = landingPos.col + c_offset
                        if r >= 0 && r < gridSize && c >= 0 && c < gridSize {
                            cellsInBlastRadius.insert(GridCoordinate(row: r, col: c))
                        }
                    }
                }
                // Patlama alanındaki hücreler, bombanın KENDİ OPAK rengine dönüşür.
                highlightCellSet(cellsInBlastRadius,
                                 baseColor: activeBlockOriginalColor.withAlphaComponent(1.0),
                                 effectType: .bombArea)

            case .rainbow:
                // --- Gökkuşağı Bloğu İçin Hedef Renk Vurgusu ---
                guard let landingPosTuple = placedBlockPositionsTuples.first else { return }
                let landingRow = landingPosTuple.row
                let landingCol = landingPosTuple.col
                
                var colorToTarget: SKColor?
                if let spriteLandedOn = gridSpriteMap[landingRow][landingCol] {
                    colorToTarget = spriteLandedOn.fillColor // Üzerine geldiği bloğun rengini hedef al
                } else {
                    // Boş hücreye denk gelirse: Mevcut clearSameColorLines mantığınız sprite olmadan çalışmıyor.
                    // Bu durumda, belki gökkuşağı bloğunun kendi rengindeki blokları vurgulayabilirsiniz
                    // ya da hiçbir şeyi vurgulamayabilirsiniz. Şimdilik bir şey yapmıyoruz.
                    // Eğer farklı bir mantık isterseniz (örn: bloğun kendi rengini hedeflemesi), bu kısım güncellenebilir.
                    return
                }

                guard let finalColorToTarget = colorToTarget else { return }
                
                var cellsToHighlightForRainbow: Set<GridCoordinate> = []
                for r_idx in 0..<gridSize {
                    for c_idx in 0..<gridSize {
                        // gridSpriteMap'teki SKShapeNode'ların fillColor'unu karşılaştır
                        if let sprite = gridSpriteMap[r_idx][c_idx], sprite.fillColor.isApproximatelyEqualTo(finalColorToTarget) {
                            cellsToHighlightForRainbow.insert(GridCoordinate(row: r_idx, col: c_idx))
                        }
                    }
                }
                // Hedeflenen bloklar KENDİ RENKLERİNDE kalır, ama özel bir efektle (örn: beyaz/parlak bir pulse) belirginleşir.
                highlightCellSet(cellsToHighlightForRainbow,
                                 baseColor: SKColor.white, // Efekt için kullanılacak renk (örn: beyaz dış çizgi/parlama)
                                 effectType: .rainbowTarget)
            }
        }
    // GameScene sınıfı içinde, highlightCellSet fonksiyonunda:

    // GameScene sınıfı içinde:
    // GameScene sınıfı içinde:
    func highlightCellSet(_ cells: Set<GridCoordinate>, baseColor: SKColor, effectType: ProspectiveHighlightEffectType) {
            // Normal hat ve bomba alanı için alpha pulse (Bu kısım aynı kalır)
            let primaryPulseAction = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.95, duration: 0.25),
                SKAction.fadeAlpha(to: 0.75, duration: 0.25)
            ])
            let primaryRepeatingPulse = SKAction.repeatForever(primaryPulseAction)

            // --- GÖKKUŞAĞI İÇİN YANIP SÖNME EFEKTİ TANIMI (DÜZELTİLMİŞ) ---
            let rainbowBlinkAction = SKAction.sequence([
                SKAction.customAction(withDuration: 0) { node, _ in
                    node.alpha = 1.0
                },
                SKAction.wait(forDuration: 0.25), // DÜZELTME: 'duration:' yerine 'forDuration:'
                SKAction.fadeAlpha(to: 0.2, duration: 0.15),
                SKAction.wait(forDuration: 0.20), // DÜZELTME: 'duration:' yerine 'forDuration:'
                SKAction.fadeAlpha(to: 1.0, duration: 0.15)
            ])
            let rainbowRepeatingBlink = SKAction.repeatForever(rainbowBlinkAction) // Yeni blink aksiyonunu tekrarla
            // --- YANIP SÖNME EFEKTİ TANIMI SONU ---

            for coord in cells {
                var targetNodeToModify: SKShapeNode?
                var nodeType: HighlightedNodeType = .gridCell

                if let existingSprite = gridSpriteMap[coord.row][coord.col] {
                    targetNodeToModify = existingSprite
                    nodeType = .existingBlockPart
                } else {
                    targetNodeToModify = gridNodes[coord.row][coord.col]
                    if effectType == .rainbowTarget && nodeType == .gridCell {
                        continue
                    }
                }

                if let nodeToHighlight = targetNodeToModify {
                    nodeToHighlight.removeAction(forKey: "prospectiveClearPulse")

                    switch effectType {
                    case .lineClear:
                        // ... (Bu case'in içeriği önceki gibi doğru) ...
                        prospectiveHighlightTargets.append((
                            node: nodeToHighlight, type: nodeType,
                            originalFillColor: nodeToHighlight.fillColor,
                            originalStrokeColor: nodeToHighlight.strokeColor,
                            originalLineWidth: nodeToHighlight.lineWidth,
                            originalAlpha: nodeToHighlight.alpha
                        ))
                        if nodeType == .existingBlockPart {
                            updateBlockPartAppearance(spriteNode: nodeToHighlight, newBaseColor: baseColor)
                        } else {
                            nodeToHighlight.fillColor = baseColor
                            nodeToHighlight.strokeColor = baseColor.darker(by: 0.25)
                        }
                        nodeToHighlight.lineWidth = 1.5
                        nodeToHighlight.run(primaryRepeatingPulse, withKey: "prospectiveClearPulse")

                    case .bombArea:
                        // ... (Bu case'in içeriği önceki gibi doğru) ...
                        if nodeType == .existingBlockPart {
                            prospectiveHighlightTargets.append((
                                node: nodeToHighlight, type: nodeType,
                                originalFillColor: nodeToHighlight.fillColor,
                                originalStrokeColor: nodeToHighlight.strokeColor,
                                originalLineWidth: nodeToHighlight.lineWidth,
                                originalAlpha: nodeToHighlight.alpha
                            ))
                            updateBlockPartAppearance(spriteNode: nodeToHighlight, newBaseColor: baseColor)
                            nodeToHighlight.lineWidth = 1.5
                            nodeToHighlight.run(primaryRepeatingPulse, withKey: "prospectiveClearPulse")
                        }

                    case .rainbowTarget:
                        if nodeType == .existingBlockPart {
                            prospectiveHighlightTargets.append((
                                node: nodeToHighlight, type: nodeType,
                                originalFillColor: nodeToHighlight.fillColor,
                                originalStrokeColor: nodeToHighlight.strokeColor,
                                originalLineWidth: nodeToHighlight.lineWidth,
                                originalAlpha: nodeToHighlight.alpha
                            ))
                            
                            nodeToHighlight.strokeColor = baseColor
                            nodeToHighlight.lineWidth = 2.0
                            
                            // DÜZELTME: rainbowRepeatingPulse yerine rainbowRepeatingBlink kullanılmalı
                            nodeToHighlight.run(rainbowRepeatingBlink, withKey: "prospectiveClearPulse")
                        }
                    }
                }
            }
        }
    
    

    override func didMove(to view: SKView) {
          
           
           if UserDefaults.standard.dictionary(forKey: "savedGameState") != nil {
               NotificationCenter.default.addObserver(self, selector: #selector(saveGameState), name: NSNotification.Name("saveGame"), object: nil)
                   setupGame() // Önce boş bir oyun alanı kur
                   loadGameState() // Sonra kayıtlı oyunu üzerine yükle
               } else {
                   setupGame() // Normal yeni oyun başlangıcı
               }
           
           let settingsButton = SKShapeNode(circleOfRadius: 24)
           settingsButton.name = "settingsButton"
           settingsButton.position = CGPoint(x: size.width - 48, y: size.height - 48)
           settingsButton.fillColor = SKColor.black.withAlphaComponent(0.72)
           settingsButton.strokeColor = SKColor.cyan
           settingsButton.lineWidth = 3
           settingsButton.zPosition = 120 // YÜKSEK ZPOZITION!
           addChild(settingsButton)

           // Glow efekti
           let glow = SKShapeNode(circleOfRadius: 30)
           glow.position = .zero
           glow.fillColor = SKColor.cyan.withAlphaComponent(0.14)
           glow.strokeColor = .clear
           glow.zPosition = -1
           settingsButton.addChild(glow)
           let pulseGlow = SKAction.sequence([
               SKAction.fadeAlpha(to: 0.30, duration: 0.7),
               SKAction.fadeAlpha(to: 0.12, duration: 0.7)
           ])
           glow.run(SKAction.repeatForever(pulseGlow))

           // Ortasına ikon
           let centerIcon = SKLabelNode(text: "☰")
           centerIcon.fontName = "AvenirNext-Bold"
           centerIcon.fontSize = 22
           centerIcon.fontColor = SKColor.cyan
           centerIcon.verticalAlignmentMode = .center
           centerIcon.horizontalAlignmentMode = .center
           centerIcon.zPosition = 2
           settingsButton.addChild(centerIcon)
              // 1. Koyu retro ana renk (gradient istersen onu da ayrıca yazarım)
              self.backgroundColor = SKColor(red: 0.08, green: 0.09, blue: 0.16, alpha: 1.0)

              // 2. Neon Glow Diskler (systemPink, systemTeal, systemIndigo yoksa fallback renk kullan)
              let neonColors: [SKColor] = [
                  SKColor(red: 1, green: 0.36, blue: 0.72, alpha: 1), // pembe
                  SKColor(red: 0.27, green: 0.86, blue: 0.96, alpha: 1), // teal
                  SKColor(red: 0.4, green: 0.35, blue: 0.88, alpha: 1), // indigo
                  SKColor(red: 1.0, green: 0.8, blue: 0.16, alpha: 1) // sarımsı
              ]
              for _ in 0..<2 {
                  let disk = SKShapeNode(circleOfRadius: CGFloat.random(in: 120...200))
                  disk.position = CGPoint(x: CGFloat.random(in: 0...size.width), y: CGFloat.random(in: 0...size.height))
                  disk.fillColor = neonColors.randomElement()!.withAlphaComponent(0.14)
                  disk.strokeColor = .clear
                  disk.zPosition = -19
                  addChild(disk)
                  let scaleUp = SKAction.scale(to: 1.14, duration: 2.8)
                  let scaleDown = SKAction.scale(to: 1.0, duration: 2.8)
                  let seq = SKAction.sequence([scaleUp, scaleDown])
                  disk.run(SKAction.repeatForever(seq))
              }

              // 3. CRT Scanline (yatay çizgiler)
              for i in stride(from: 0, to: Int(size.height), by: 8) {
                  let line = SKShapeNode(rectOf: CGSize(width: size.width, height: 1))
                  line.position = CGPoint(x: size.width/2, y: CGFloat(i))
                  line.fillColor = SKColor.white.withAlphaComponent(0.06)
                  line.strokeColor = .clear
                  line.zPosition = -18
                  addChild(line)
              }

              // 4. Neon geometrik desenler
              let shapeColors: [SKColor] = [
                  SKColor.cyan.withAlphaComponent(0.25),
                  SKColor.magenta.withAlphaComponent(0.23),
                  SKColor.yellow.withAlphaComponent(0.19),
                  SKColor.white.withAlphaComponent(0.14)
              ]
              for _ in 0..<5 {
                  let sides = [3, 4, 6, 8].randomElement()!
                  let path = UIBezierPath()
                  let r = CGFloat.random(in: 40...80)
                  for i in 0..<sides {
                      let angle = CGFloat(i) * (2 * .pi / CGFloat(sides))
                      let point = CGPoint(x: cos(angle) * r, y: sin(angle) * r)
                      if i == 0 { path.move(to: point) }
                      else { path.addLine(to: point) }
                  }
                  path.close()
                  let shape = SKShapeNode(path: path.cgPath)
                  shape.position = CGPoint(x: CGFloat.random(in: 0...size.width), y: CGFloat.random(in: 0...size.height))
                  shape.strokeColor = shapeColors.randomElement()!
                  shape.lineWidth = 2
                  shape.zPosition = -17
                  addChild(shape)
              }

              // 5. Pixel yıldızlar
              let starColors: [SKColor] = [
                  .white,
                  SKColor(red: 1, green: 0.96, blue: 0.6, alpha: 1), // sarımsı
                  SKColor(red: 1, green: 0.6, blue: 0.8, alpha: 1), // pembe
                  SKColor(red: 0.7, green: 1, blue: 1, alpha: 1), // cyan
                  SKColor(red: 1, green: 0.8, blue: 0.36, alpha: 1)
              ]
              for _ in 0..<40 {
                  let s = CGFloat.random(in: 1...3)
                  let star = SKShapeNode(rectOf: CGSize(width: s, height: s))
                  star.fillColor = starColors.randomElement()!.withAlphaComponent(.random(in: 0.12...0.38))
                  star.strokeColor = .clear
                  star.isAntialiased = false
                  star.position = CGPoint(x: .random(in: 0...size.width), y: .random(in: 0...size.height))
                  star.zPosition = -16
                  addChild(star)
              }

              
          }

    func setupGame() {
        backgroundColor = SKColor(red: 0.1, green: 0.12, blue: 0.2, alpha: 1.0)
        previewContainer.zPosition = 100
        addChild(previewContainer)
        let safeTop = view?.safeAreaInsets.top ?? 44
        let panelYOffset: CGFloat = 120 // Eskiden 50 idi, şimdi 120
               let panel = SKShapeNode(rectOf: CGSize(width: 330, height: 72), cornerRadius: 18)
               panel.position = CGPoint(x: size.width / 2, y: size.height - safeTop - panelYOffset)
               panel.fillColor = SKColor.black.withAlphaComponent(0.45)
               panel.strokeColor = .white.withAlphaComponent(0.09)
               panel.zPosition = 100
               addChild(panel)
               topPanel = panel
        scoreLabel = SKLabelNode(fontNamed: "PressStart2P-Regular")
        scoreLabel.fontSize = 14
        scoreLabel.fontColor = .white
        scoreLabel.text = "Skor: 0"
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.position = CGPoint(x: -130, y: 12)
        panel.addChild(scoreLabel)
        let highScoreLabel = SKLabelNode(fontNamed: "PressStart2P-Regular")
        highScoreLabel.name = "highScoreLabel"
        highScoreLabel.fontSize = 12
        highScoreLabel.fontColor = .systemYellow
        highScoreLabel.text = "En Yüksek: \(UserDefaults.standard.integer(forKey: "HighScore"))"
        highScoreLabel.horizontalAlignmentMode = .left
        highScoreLabel.position = CGPoint(x: -130, y: -18)
        panel.addChild(highScoreLabel)
        // --- Döndürme Butonu ---
            rotateButton = SKSpriteNode(color: .clear, size: CGSize(width: 58, height: 58))
            rotateButton.position = CGPoint(x: 120, y: 0)
            rotateButton.name = "rotateButton"

            // Neon Glow Çerçeve
            let rotateGlow = SKShapeNode(circleOfRadius: 29)
            rotateGlow.fillColor = SKColor.systemPink.withAlphaComponent(0.18)
            rotateGlow.strokeColor = SKColor.cyan.withAlphaComponent(0.4)
            rotateGlow.lineWidth = 3
            rotateGlow.zPosition = -1
            rotateButton.addChild(rotateGlow)
            // Hafif parlama efekti
            let glowPulse = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.36, duration: 0.8),
                SKAction.fadeAlpha(to: 0.18, duration: 0.8)
            ])
            rotateGlow.run(SKAction.repeatForever(glowPulse))

            // Buton ikonu: ↻, retro renkli, büyük ve canlı
            let label = SKLabelNode(text: "↻")
            label.fontName = "AvenirNext-Bold"
            label.fontSize = 30
            label.fontColor = SKColor.yellow
            label.verticalAlignmentMode = .center
            label.zPosition = 2
            rotateButton.addChild(label)
        
        // GameScene.swift -> setupGame() fonksiyonu içine

        // --- Duraklatma Butonu ---
        let pauseButton = SKShapeNode(rectOf: CGSize(width: 58, height: 58), cornerRadius: 14)
        pauseButton.name = "pauseButton"
        pauseButton.fillColor = SKColor.black.withAlphaComponent(0.45)
        pauseButton.strokeColor = SKColor.cyan.withAlphaComponent(0.6)
        pauseButton.lineWidth = 2
        // Pozisyonu ayarlar butonuna veya skor paneline göre ayarla. Örnek:
        pauseButton.position = CGPoint(x: -size.width/2 + 50, y: size.height - safeTop - 50)
        pauseButton.zPosition = 110
        addChild(pauseButton)

        // Butonun içine "II" şeklinde ikon yapalım
        let pauseIconBar1 = SKShapeNode(rectOf: CGSize(width: 6, height: 24), cornerRadius: 3)
        pauseIconBar1.fillColor = .white
        pauseIconBar1.strokeColor = .clear
        pauseIconBar1.position = CGPoint(x: -8, y: 0)
        pauseButton.addChild(pauseIconBar1)

        let pauseIconBar2 = SKShapeNode(rectOf: CGSize(width: 6, height: 24), cornerRadius: 3)
        pauseIconBar2.fillColor = .white
        pauseIconBar2.strokeColor = .clear
        pauseIconBar2.position = CGPoint(x: 8, y: 0)
        pauseButton.addChild(pauseIconBar2)

        // Butonu topPanel'e eklemek istersen, addChild(pauseButton) yerine:
        // pauseButton.position = CGPoint(x: -120, y: 0) // Panelin kendi koordinat sistemine göre
        // panel.addChild(pauseButton)

            // "Kilitli" durum göstergesi: Gerçek kilit emojisi yerine neon efektiyle çapraz bir çizgi
            let lockBar = SKShapeNode(rectOf: CGSize(width: 38, height: 6), cornerRadius: 3)
            lockBar.fillColor = SKColor.red.withAlphaComponent(0.9)
            lockBar.strokeColor = SKColor.red
            lockBar.zRotation = CGFloat.pi / 5
            lockBar.alpha = 0 // Başta görünmez
            lockBar.position = CGPoint(x: 0, y: 0)
            lockBar.name = "lockBar"
            rotateButton.addChild(lockBar)

            panel.addChild(rotateButton)
        gridState = Array(repeating: Array(repeating: 0, count: gridSize), count: gridSize)
        gridNodes = Array(repeating: Array(repeating: SKShapeNode(), count: gridSize), count: gridSize)
        gridSpriteMap = Array(repeating: Array(repeating: nil, count: gridSize), count: gridSize)
        gridOrigin = CGPoint(
            x: (size.width - CGFloat(gridSize) * cellSize) / 2,
            y: (size.height - CGFloat(gridSize) * cellSize) / 2
        )
        drawGrid()
        spawnNextBlocks()
        updateRotateButtonState()
    }

    func drawGrid() {
            // 1. Grid Etrafındaki "glow" Efektini Kaldırın
            // addChild(glow) satırını ve glow ile ilgili tüm tanımlamayı
            // yorum satırı yapın veya silin.
            /*
            let glow = SKShapeNode(rectOf: CGSize(width: cellSize * CGFloat(gridSize) + 20, height: cellSize * CGFloat(gridSize) + 20))
            glow.fillColor = .white
            glow.alpha = 0.04
            glow.zPosition = -3
            glow.position = CGPoint(x: size.width / 2, y: size.height / 2)
            addChild(glow)
            */

            // 2. "gridBackground"u (Grid Alanının Arka Planı) Basitleştirin
            let gridBackground = SKShapeNode(rectOf: CGSize(width: cellSize * CGFloat(gridSize), height: cellSize * CGFloat(gridSize)),
                                             cornerRadius: 0) // Köşeleri keskin yapın: 0 veya çok küçük (2-3)
            
            // gridBackground için ana sahne arka planından ayırt edilebilir ama yine de koyu bir renk:
            gridBackground.fillColor = SKColor(white: 0.15, alpha: 1.0) // Örnek: Koyu Gri
            // VEYA ana sahne arka planına göre bir ton:
            // gridBackground.fillColor = self.backgroundColor.darker(by: -0.1) // Sahne BG'den biraz açık
            
            gridBackground.strokeColor = .clear // Kenar çizgisi istemiyoruz veya çok belirsiz
            gridBackground.lineWidth = 0      // Kenar çizgisi kalınlığı
            gridBackground.isAntialiased = false // Keskin görünüm
            
            gridBackground.position = CGPoint(x: size.width / 2, y: size.height / 2)
            gridBackground.zPosition = -2 // Sahne arka planının üzerinde, hücrelerin altında
            addChild(gridBackground)

            // 3. Bireysel Grid Hücrelerini ("cell") Yeniden Tasarlayın
            for row in 0..<gridSize {
                for col in 0..<gridSize {
                    // Hücre boyutunu tam cellSize yapın, köşe yuvarlamasını kaldırın veya çok azaltın
                    let cell = SKShapeNode(rectOf: CGSize(width: cellSize, height: cellSize), cornerRadius: 0) // Keskin köşeler
                    
                    // Boş hücrelerin dolgu rengi: gridBackground'dan daha koyu olmalı
                    // Bu, "içi boş delikler" görünümü verecektir.
                    cell.fillColor = SKColor(white: 0.08, alpha: 1.0) // Örnek: Çok Koyu Gri / Neredeyse Siyah
                    // VEYA gridBackground rengine göre:
                    // cell.fillColor = gridBackground.fillColor.darker(by: 0.2)
                    
                    cell.strokeColor = .clear // Hücreler arası çizgi olmasın, ayrımı dolgu renkleri yapsın
                    cell.lineWidth = 0
                    cell.isAntialiased = false // Keskin pixel görünümü

                    cell.position = gridPositionToPoint(row: row, col: col)
                    cell.zPosition = -1 // gridBackground'un üzerinde, blokların altında
                    gridNodes[row][col] = cell
                    addChild(cell)
                }
            }
        }

    func updateRotateButtonState() {
        guard rotateButton != nil else { return }
        rotateButton.alpha = rotateUsed ? 0.3 : 1.0
        if let lockIcon = rotateButton.childNode(withName: "lockIcon") {
            lockIcon.alpha = rotateUsed ? 1.0 : 0.0
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            // 1. Ayarlar paneli zaten açıksa, sadece panel içindeki dokunmaları işle
            if isSettingsPanelDisplayed {
                guard let touch = touches.first, let panel = childNode(withName: "settingsPanel") else { return }
                let locationInPanel = touch.location(in: panel)
                var tappedNode = panel.atPoint(locationInPanel)
                if tappedNode.name == nil { tappedNode = tappedNode.parent ?? tappedNode }

                let tapAction = SKAction.sequence([.scale(to: 1.15, duration: 0.08), .scale(to: 1.0, duration: 0.08)])

                switch tappedNode.name {
                case "soundToggle", "hapticToggle":
                    tappedNode.run(tapAction)
                    if tappedNode.name == "soundToggle" {
                        Settings.isSoundEnabled.toggle()
                        (tappedNode as? SKSpriteNode)?.texture = SKTexture(imageNamed: Settings.isSoundEnabled ? "toggle_on_icon" : "toggle_off_icon")
                    } else {
                        Settings.isHapticEnabled.toggle()
                        (tappedNode as? SKSpriteNode)?.texture = SKTexture(imageNamed: Settings.isHapticEnabled ? "toggle_on_icon" : "toggle_off_icon")
                    }
                case "restartSettingsButton":
                    tappedNode.run(tapAction) { [weak self] in
                        self?.isSettingsPanelDisplayed = false
                        panel.removeFromParent()
                        self?.childNode(withName: "settingsOverlay")?.removeFromParent()
                        self?.restartGame()
                    }
                case "menuSettingsButton":
                     tappedNode.run(tapAction) { [weak self] in
                        if let view = self?.view {
                            let menuScene = MenuScene(size: self!.size)
                            menuScene.scaleMode = self!.scaleMode
                            view.presentScene(menuScene, transition: .fade(withDuration: 0.75))
                        }
                     }
                case "closeSettings":
                    tappedNode.run(tapAction) { [weak self] in
                        self?.isSettingsPanelDisplayed = false
                        panel.removeFromParent()
                        self?.childNode(withName: "settingsOverlay")?.removeFromParent()
                    }
                default:
                    break
                }
                return
            }

            // --- Panel kapalıyken çalışacak normal dokunma mantığı ---
            guard let touch = touches.first else { return }
            
            // Bir blok zaten sürükleniyorsa, başka bir dokunma işlemi başlatma.
            guard selectedNode == nil else { return }

            let location = touch.location(in: self)
            let initiallyTouchedNode = atPoint(location)

            if initiallyTouchedNode.name == "restartButton" || initiallyTouchedNode.parent?.name == "restartButton" { restartGame(); return }
            if initiallyTouchedNode.name == "menuButton" || initiallyTouchedNode.parent?.name == "menuButton" {
                 if let view = self.view { let menuScene = MenuScene(size: self.size); menuScene.scaleMode = self.scaleMode; view.presentScene(menuScene, transition: SKTransition.fade(withDuration: 0.75)) }; return
            }
            if initiallyTouchedNode.name == "settingsButton" || initiallyTouchedNode.parent?.name == "settingsButton" {
                guard !isSettingsPanelDisplayed else { return }
                isSettingsPanelDisplayed = true
                showSettingsMenu()
                if Settings.isHapticEnabled { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                return
            }
            var nodeForRotateCheck: SKNode? = initiallyTouchedNode
            var didTapRotateButton = false
            while nodeForRotateCheck != nil {
                if nodeForRotateCheck?.name == "rotateButton" { didTapRotateButton = true; break }
                if nodeForRotateCheck == self { break }
                nodeForRotateCheck = nodeForRotateCheck?.parent
            }
            
            // --- DÜZELTİLMİŞ DÖNDÜRME MANTIĞI ---
            // Döndürme butonu artık sadece bloğu döndürür ve seçim durumunu değiştirmez.
            if didTapRotateButton, !rotateUsed, let firstBlock = nextBlocks.first {
                rotateBlock(firstBlock)
                rotateUsed = true
                updateRotateButtonState()
                return // İşlemi burada bitirerek sürükleme mantığına geçmesini engelliyoruz.
            }
            
            // --- SÜRÜKLEME MANTIĞI ---
            var currentNodeForDrag: SKNode? = initiallyTouchedNode
            var draggableBlockNode: BlockNode? = nil
            while currentNodeForDrag != nil {
                if let foundNode = currentNodeForDrag as? BlockNode, foundNode.name == "draggable" { draggableBlockNode = foundNode; break }
                if currentNodeForDrag == self { break }
                currentNodeForDrag = currentNodeForDrag?.parent
            }
            if let foundDraggableNode = draggableBlockNode, let firstBlockToDrag = nextBlocks.first, foundDraggableNode == firstBlockToDrag {
                if Settings.isSoundEnabled {
                        run(SKAction.playSoundFileNamed("place.wav", waitForCompletion: false))
                    }
                selectedNode = foundDraggableNode
                selectedNode?.zPosition = 10
                lastValidPosition = foundDraggableNode.position
                isDragging = true
                blockOffset = CGPoint(x: foundDraggableNode.position.x - location.x, y: foundDraggableNode.position.y - location.y)
                selectedNode?.run(SKAction.scale(to: 1.0, duration: 0.08))
            }
        }

    // GameScene sınıfı içinde:
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
          guard let touch = touches.first, let node = selectedNode, isDragging else { return }
          let location = touch.location(in: self)
          let newPosition = CGPoint(x: location.x + blockOffset.x, y: location.y + blockOffset.y)
             node.position = newPosition

          // 1. Tüm eski vurgulamaları temizle
          resetProspectiveHighlights() // Özel "aktif blok rengi + pulse" vurgularını temizler
          resetGridHighlight()       // Standart gridNode ayak izi vurgusunu (yeşil/kırmızı için hazırlık) sıfırlar

          if let positions = getBlockGridPositions(node) { // Bu [(row: Int, col: Int)] döndürür
              let isValid = isValidPlacement(positions)
              node.alpha = isValid ? 1.0 : 0.5

              // 2. Standart ayak izi vurgusunu (yeşil/kırmızı) uygula
              highlightGrid(positions: positions, isValid: isValid)

              // 3. Eğer yerleşim geçerliyse, yeni "temizlenecek hat" vurgusunu uygula
              if isValid {
                  applyProspectiveClearHighlight(forPlacing: positions, activeBlockNode: node as? BlockNode)
              }
              // Geçersiz yerleşimde ekstra bir 'else' bloğuna gerek yok, çünkü yukarıdaki reset fonksiyonları
              // ve highlightGrid(isValid: false) durumu zaten yönetiyor.
          }
      }
    
    func previewClearingLinesWithBlockColor(for positions: [(row: Int, col: Int)], blockColor: SKColor) {
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                gridNodes[row][col].removeAction(forKey: "previewGlow")
                gridNodes[row][col].fillColor = .clear
            }
        }

        var tempGrid = gridState
        for pos in positions {
            if pos.row >= 0 && pos.row < gridSize && pos.col >= 0 && pos.col < gridSize {
                tempGrid[pos.row][pos.col] = 1
            }
        }
        var fullRows: [Int] = []
        var fullCols: [Int] = []
        for row in 0..<gridSize {
            if tempGrid[row].allSatisfy({ $0 == 1 }) {
                fullRows.append(row)
            }
        }
        for col in 0..<gridSize {
            if (0..<gridSize).allSatisfy({ row in tempGrid[row][col] == 1 }) {
                fullCols.append(col)
            }
        }
        let highlightColor = blockColor.withAlphaComponent(0.45)
        for row in fullRows {
            for col in 0..<gridSize {
                let cell = gridNodes[row][col]
                cell.fillColor = highlightColor
                let pulse = SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.7, duration: 0.13),
                    SKAction.fadeAlpha(to: 1.0, duration: 0.15)
                ])
                cell.run(SKAction.repeatForever(pulse), withKey: "previewGlow")
            }
        }
        for col in fullCols {
            for row in 0..<gridSize {
                let cell = gridNodes[row][col]
                cell.fillColor = highlightColor
                let pulse = SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.7, duration: 0.13),
                    SKAction.fadeAlpha(to: 1.0, duration: 0.15)
                ])
                cell.run(SKAction.repeatForever(pulse), withKey: "previewGlow")
            }
        }
    }

    func resetGridHighlight() {
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                gridNodes[row][col].removeAction(forKey: "previewGlow")
                gridNodes[row][col].fillColor = .clear
                gridNodes[row][col].strokeColor = SKColor.white.withAlphaComponent(0.09)
                gridNodes[row][col].lineWidth = 1
            }
        }
    }


    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            // --- 1. Kilit Kontrolü ---
            // Eğer başka bir blok yerleştirme işlemi zaten devam ediyorsa, bu dokunmayı tamamen yoksay.
            guard !isProcessingPlacement else { return }
            
            // --- 2. Gerekli Değişkenlerin Kontrolü ---
            guard let node = selectedNode, isDragging else {
                // Eğer sürüklenen bir düğüm yoksa, bir anormallik olabilir, kilidin aktif olmadığından emin ol.
                isProcessingPlacement = false
                return
            }
            
            // --- 3. KİLİDİ DEVREYE AL ---
            // Dokunma işlemini işlemeye başlıyoruz, bu yüzden başka bir dokunmanın araya girmemesi için sistemi kilitle.
            isProcessingPlacement = true
            isDragging = false

            // --- 4. Yerleştirme Mantığı ---
            if let positions = getBlockGridPositions(node), isValidPlacement(positions) {
                
                // --- BAŞARILI YERLEŞTİRME ---
                
                guard positions.count == node.children.count else {
                    returnToLastValidPosition(node)
                    return
                }
                
                for (index, pos) in positions.enumerated() {
                    if let shapeNode = node.children[index] as? SKShapeNode {
                        setGridValue(1, at: pos, sprite: shapeNode)
                        shapeNode.userData = shapeNode.userData ?? NSMutableDictionary()
                        shapeNode.userData?["originalColor"] = shapeNode.fillColor
                    }
                }
                
                snapAndPlaceBlock(node, at: positions)
                
                saveGameState()
                
                if let index = nextBlocks.firstIndex(of: node) {
                    nextBlocks.remove(at: index)
                    if nextBlocks.isEmpty {
                        spawnNextBlocks()
                    } else if nextBlocks.count == 1 {
                        let leftPos = CGPoint(x: size.width/2 - 90, y: 100)
                        let block = nextBlocks[0]
                        block.position = leftPos
                        if block.parent == nil { addChild(block) }
                        
                        let shape   = generateRandomShape()
                        let newPos  = CGPoint(x: size.width/2 + 90, y: 100)
                        let newBloc = spawnBlock(from: shape, at: newPos)
                        newBloc.setScale(0.8)
                        nextBlocks.append(newBloc)
                        
                        updateBottomBlockStyles()
                        rotateUsed = false
                        updateRotateButtonState()
                    }
                }
                
                layoutPreview()
                checkGameOver()
                
                // Görsel Efektler
                let bounce = SKAction.sequence([.scale(to: 1.14, duration: 0.09), .scale(to: 1.0, duration: 0.09)])
                node.run(bounce)
                
                let halo = SKShapeNode(circleOfRadius: cellSize/1.7)
                halo.position = node.position
                halo.fillColor = .yellow
                halo.alpha = 0.19
                halo.zPosition = 120
                addChild(halo)
                halo.run(.sequence([.scale(to: 2.1, duration: 0.22), .fadeOut(withDuration: 0.22), .removeFromParent()]))
                
                // KİLİDİ GÜVENLE AÇ
                // Animasyonların bitmesi için küçük bir bekleme sonrası kilidi aç.
                let unlockAction = SKAction.run { [weak self] in self?.isProcessingPlacement = false }
                self.run(SKAction.sequence([SKAction.wait(forDuration: 0.3), unlockAction]))

            } else {
                // --- GEÇERSİZ YERLEŞTİRME ---
                // Bloğu eski yerine döndür. Bu fonksiyon kendi içinde kilidi açmaktan sorumlu.
                node.run(SKAction.scale(to: 0.8, duration: 0.1))
                returnToLastValidPosition(node)
            }
            
            // --- 5. Temizlik ---
            // Bu işlemler kilidin durumundan bağımsız olarak, dokunma bittiğinde yapılmalı.
            resetProspectiveHighlights()
            resetGridHighlight()
            selectedNode = nil
        }

    func getBlockGridPositions(_ node: SKNode) -> [(row: Int, col: Int)]? {
        var positions: [(row: Int, col: Int)] = []
        for square in node.children {
            guard let part = square as? SKShapeNode else { continue }
            let worldPos = node.convert(part.position, to: self)
            guard let pos = pointToGridPosition(worldPos) else { return nil }
            positions.append(pos)
        }
        return positions.count == node.children.count ? positions : nil
    }

    func pointToGridPosition(_ point: CGPoint) -> (row: Int, col: Int)? {
        let relativeX = point.x - gridOrigin.x
        let relativeY = point.y - gridOrigin.y
        let col = Int(floor(relativeX / cellSize))
        let row = Int(floor(relativeY / cellSize))
        if row >= 0 && row < gridSize && col >= 0 && col < gridSize {
            return (row, col)
        }
        return nil
    }

    func gridPositionToPoint(row: Int, col: Int) -> CGPoint {
        return CGPoint(
            x: gridOrigin.x + CGFloat(col) * cellSize + cellSize / 2,
            y: gridOrigin.y + CGFloat(row) * cellSize + cellSize / 2
        )
    }

    func isValidPlacement(_ positions: [(row: Int, col: Int)]) -> Bool {
        for pos in positions {
            if pos.row < 0 || pos.row >= gridSize || pos.col < 0 || pos.col >= gridSize {
                return false
            }
            if getGridValue(at: pos) != 0 {
                return false
            }
        }
        return true
    }
    private func getPlacementOutcome(for node: SKNode, at positions: [(row: Int, col: Int)]) -> SoundEvent {
            // 1. Özel blok kontrolü
            if let blockNode = node as? BlockNode {
                if blockNode.blockShape.type == .bomb { return .bomb }
                if blockNode.blockShape.type == .rainbow { return .rainbow }
            }

            // 2. Sıra tamamlama ve kombo kontrolü
            var tempGrid = gridState
            for pos in positions {
                if pos.row >= 0 && pos.row < gridSize && pos.col >= 0 && pos.col < gridSize {
                    tempGrid[pos.row][pos.col] = 1
                }
            }
            
            var rowsToClear: [Int] = []
            for r in 0..<gridSize { if tempGrid[r].allSatisfy({ $0 == 1 }) { rowsToClear.append(r) } }
            
            var colsToClear: [Int] = []
            for c in 0..<gridSize { if (0..<gridSize).allSatisfy({ r in tempGrid[r][c] == 1 }) { colsToClear.append(c) } }
            
            let totalLinesCleared = rowsToClear.count + colsToClear.count
            
            if totalLinesCleared >= 2 {
                return .combo
            } else if totalLinesCleared > 0 {
                return .lineClear
            }
            
            // 3. Hiçbiri değilse, bu basit bir yerleştirmedir.
            return .place
        }
    func snapAndPlaceBlock(_ node: SKNode, at positions: [(row: Int, col: Int)]) {
        guard let firstSquare = node.children.first as? SKShapeNode else { return }
        guard let firstPosition = positions.first else { return }
        let firstSquareWorldPos = node.convert(firstSquare.position, to: self)
        let targetGridPos = gridPositionToPoint(row: firstPosition.row, col: firstPosition.col)
        let offset = CGPoint(
            x: targetGridPos.x - firstSquareWorldPos.x,
            y: targetGridPos.y - firstSquareWorldPos.y
        )
        let finalPosition = CGPoint(
            x: node.position.x + offset.x,
            y: node.position.y + offset.y
        )
        node.run(SKAction.move(to: finalPosition, duration: 0.1))
        if let blockNode = node as? BlockNode {
            switch blockNode.blockShape.type {
            case .bomb:
                let pos = positions.first!
                clearAreaAround(row: pos.row, col: pos.col)
            case .rainbow:
                let pos = positions.first!
                clearSameColorLines(row: pos.row, col: pos.col)
            case .normal:
                break
            }
        }
        node.zPosition = 0
        node.alpha = 1.0
        lastValidPosition = finalPosition
        checkAndClearLines()
    }

    private func setGridValue(_ value: Int, at position: (row: Int, col: Int), sprite: SKShapeNode? = nil) {
        gridState[position.row][position.col] = value
        gridSpriteMap[position.row][position.col] = sprite
    }

    private func getGridValue(at position: (row: Int, col: Int)) -> Int {
        return gridState[position.row][position.col]
    }

    func highlightGrid(positions: [(row: Int, col: Int)], isValid: Bool) {
        resetGridHighlight()
        positions.forEach { pos in
            if pos.row >= 0 && pos.row < gridSize && pos.col >= 0 && pos.col < gridSize {
                gridNodes[pos.row][pos.col].fillColor = isValid
                    ? SKColor.green.withAlphaComponent(0.22)
                    : SKColor.red.withAlphaComponent(0.18)
                gridNodes[pos.row][pos.col].strokeColor = isValid
                    ? SKColor.green.withAlphaComponent(0.55)
                    : SKColor.red.withAlphaComponent(0.49)
                gridNodes[pos.row][pos.col].lineWidth = isValid ? 3 : 2
            }
        }
    }


    func returnToLastValidPosition(_ node: SKNode) {
            if let lastPos = lastValidPosition {
                
                // 1. Animasyon bittiğinde kilidi açacak olan eylemi oluştur.
                //    Bu, en önemli adımdır.
                let unlockAction = SKAction.run { [weak self] in
                    self?.isProcessingPlacement = false
                }
                
                // 2. Orijinal kodundaki animasyon ve state güncelleme eylemlerini al.
                let moveAction = SKAction.move(to: lastPos, duration: 0.2)
                let updateStateAction = SKAction.run { [weak self] in
                    guard let self = self else { return }
                    node.alpha = 1.0
                    // Not: Parmağı kaldırdığımızda bloğun grid'deki eski yerini zaten
                    // siliyoruz. Geçersiz bir yerleştirmede bu değeri tekrar 1 yapmak
                    // hatalara yol açabilir. Bu yüzden o kısmı yorum satırı yapmak
                    // daha güvenli olabilir, ama şimdilik orijinal mantığı koruyorum.
                    if let positions = self.getBlockGridPositions(node) {
                        for pos in positions {
                            self.setGridValue(1, at: pos)
                        }
                    }
                }
                
                // 3. Tüm eylemleri bir dizi (sequence) halinde çalıştır.
                //    Sıra: Önce bloğu hareket ettir, sonra durumunu güncelle,
                //    VE EN SONUNDA kilidi aç.
                node.run(SKAction.sequence([moveAction, updateStateAction, unlockAction]))
                
            } else {
                // 4. Eğer bir sebepten `lastPos` bulunamazsa, oyunun kilitli kalmaması
                //    için kilidi burada da açmak çok önemlidir.
                isProcessingPlacement = false
            }
        }

    func rotateBlock(_ node: SKNode) {
        guard node.children.count > 0 else { return }

        // 1. Çocuk node'ların mevcut lokal pozisyonlarını al.
        let originalChildLocalPositions = node.children.compactMap { $0.position }

        // 2. Bu lokal pozisyonlara göre bir merkez noktası hesapla.
        let centerX = originalChildLocalPositions.map { $0.x }.reduce(0, +) / CGFloat(originalChildLocalPositions.count)
        let centerY = originalChildLocalPositions.map { $0.y }.reduce(0, +) / CGFloat(originalChildLocalPositions.count)
        let centerOfShapeLocally = CGPoint(x: centerX, y: centerY)

        // 3. Her bir çocuk node'un lokal pozisyonunu bu lokal merkeze göre döndür.
        for (index, square) in node.children.enumerated() {
            let localPos = originalChildLocalPositions[index]
            let translatedPos = CGPoint(x: localPos.x - centerOfShapeLocally.x, y: localPos.y - centerOfShapeLocally.y)
            let rotatedPos = CGPoint(x: -translatedPos.y, y: translatedPos.x) // 90 derece saat yönünde
            square.position = CGPoint(x: rotatedPos.x + centerOfShapeLocally.x, y: rotatedPos.y + centerOfShapeLocally.y)
        }

        // 4. İsteğe bağlı: Ana node için görsel bir döndürme animasyonu (bu mantığı etkilememeli)
        // node.run(SKAction.rotate(byAngle: .pi / 2, duration: 0.1)) // Eğer bu varsa, canPlaceBlock'un
                                                                  // node.convert kullanırken doğru çalıştığından emin olun.
                                                                  // Genelde ya çocukların pozisyonu ya da parent'ın zRotation'ı
                                                                  // mantık için kullanılır, ikisi birden dikkat gerektirir.
                                                                  // En temizi, mantığı güncellenmiş çocuk pozisyonlarına dayandırmak.

        // !!! ÖNEMLİ: Burada, döndürme sonrası "eğer mevcut yerde geçersizse geri al" GİBİ BİR MANTIK OLMAMALI !!!
        // Blok, mantıksal olarak DÖNMÜŞ HALDE KALMALI.

        // 5. asyncAfter bloğu (daha önce önerildiği gibi)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self, let currentRotatedBlock = self.nextBlocks.first else { return }
            // currentRotatedBlock'un yukarıda güncellenen DÖNMÜŞ çocuk pozisyonlarına sahip olması beklenir.
            if !self.canPlaceBlock(currentRotatedBlock, considerRotation: false) {
                self.showGameOver()
            }
        }
    }

    func spawnNextBlocks() {
            for block in nextBlocks { block.removeFromParent() }
            nextBlocks.removeAll()
            let y: CGFloat = 100
            let dx: CGFloat = 90
            let pos = [
                CGPoint(x: size.width/2 - dx, y: y),
                CGPoint(x: size.width/2 + dx, y: y)
            ]
            for i in 0..<2 {
                let shape = generateRandomShape()
                let block = spawnBlock(from: shape, at: pos[i])
                block.setScale(0.8)
                if i == 0 {
                    addChild(block) // SADECE İLK BLOK SAHNEYE EKLENİR!
                }
                nextBlocks.append(block)
            }
            // nextBlocks[0].run( ... ) animasyonunu SİL veya YORUM SATIRI YAP!
            // nextBlocks[0].run(
            //    SKAction.sequence([ .scale(to: 1.1, duration: 0.12),
            //                        .scale(to: 1.0, duration: 0.12) ])
            // )
            rotateUsed = false
            selectedNode = nil
            updateRotateButtonState()
            layoutPreview()
            checkGameOver()
            updateBottomBlockStyles()
        }


    func generateRandomShape() -> BlockShape {
        let shapes: [[(Int, Int)]] = [
            [(0,0), (1,0), (1,1)],
            [(0,0), (0,1), (0,2)],
            [(0,0), (1,0), (0,1), (1,1)],
            [(0,0), (1,0), (2,0), (3,0)],
            [(0,0), (0,1), (0,2), (1,2)],
            [(0,0), (1,0), (1,1), (2,1)],
            [(0,0), (1,0), (2,0), (2,1)],
            [(0,0), (1,0), (1,-1), (1,1)],
            [(0,0), (0,1), (1,1), (1,2)],
            [(0,0), (1,0), (2,0), (2,-1)]
        ]
        let colors: [SKColor] = [
            .cyan, .orange, .green, .yellow,
            .systemPink, .magenta, .blue, .systemRed, .purple
        ]
        let randomIndex = Int.random(in: 0..<shapes.count)
        let randomColor = colors.randomElement() ?? .white
        let rand = Double.random(in: 0...1)
        var type: BlockType = .normal
        if rand < 0.10 { type = .bomb }
        else if rand < 0.20 { type = .rainbow }
        return BlockShape(cells: shapes[randomIndex], color: randomColor, type: type)
    }

    func showGameOver() {
        // 1. Temalı Overlay
        let overlay = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height))
        overlay.position = CGPoint(x: size.width / 2, y: size.height / 2)
        overlay.fillColor = SKColor(red: 0.05, green: 0.05, blue: 0.15, alpha: 0.85) // Koyu neon dostu renk
        overlay.strokeColor = .clear
        overlay.zPosition = 1000
        overlay.name = "gameOverOverlay"
        overlay.alpha = 0 // Animasyonla belirecek
        addChild(overlay)
        overlay.run(SKAction.fadeIn(withDuration: 0.3))

        // 2. Oyun Sonu Paneli (Tüm elemanları içerecek)
        let panelWidth = size.width * 0.8
        let panelHeight = size.height * 0.6
        let panelCornerRadius: CGFloat = 5 // Keskin köşeler için küçük bir değer
        let gameOverPanel = SKShapeNode(rectOf: CGSize(width: panelWidth, height: panelHeight), cornerRadius: panelCornerRadius)
        gameOverPanel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        gameOverPanel.fillColor = SKColor.black.withAlphaComponent(0.6) // Yarı şeffaf koyu panel
        gameOverPanel.strokeColor = SKColor.cyan.withAlphaComponent(0.7) // Neon kenarlık
        gameOverPanel.lineWidth = 2
        gameOverPanel.zPosition = overlay.zPosition + 1
        gameOverPanel.name = "gameOverPanel"
        gameOverPanel.alpha = 0
        gameOverPanel.setScale(0.7) // Animasyon için başlangıç ölçeği
        addChild(gameOverPanel)

        // 3. "OYUN BİTTİ" Başlığı
        let gameOverLabel = SKLabelNode(text: "OYUN BİTTİ")
        gameOverLabel.name = "gameOverLabel"
        gameOverLabel.fontName = "PressStart2P-Regular"
        gameOverLabel.fontSize = 28 // Boyut iyi
        gameOverLabel.fontColor = SKColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0) // Canlı neon kırmızı
        gameOverLabel.position = CGPoint(x: 0, y: panelHeight / 2 - 60) // Panel içine göre pozisyon
        gameOverLabel.zPosition = 1 // Panel üzerinde
        // gameOverPanel.addChild(gameOverLabel) // Animasyondan sonra eklenecek

        // Sert Gölge
        let shadowLabel = SKLabelNode(text: "OYUN BİTTİ")
        shadowLabel.fontName = "PressStart2P-Regular"
        shadowLabel.fontSize = gameOverLabel.fontSize
        shadowLabel.fontColor = SKColor.black.withAlphaComponent(0.7)
        let shadowOffset: CGFloat = 2
        shadowLabel.position = CGPoint(x: gameOverLabel.position.x + shadowOffset, y: gameOverLabel.position.y - shadowOffset)
        shadowLabel.zPosition = gameOverLabel.zPosition - 1
        // gameOverPanel.addChild(shadowLabel) // Animasyondan sonra eklenecek

        // 4. Skor Yazıları
        let finalScoreLabel = SKLabelNode(fontNamed: "PressStart2P-Regular")
        finalScoreLabel.text = "SKOR: \(score)"
        finalScoreLabel.fontSize = 18
        finalScoreLabel.fontColor = .white
        finalScoreLabel.position = CGPoint(x: 0, y: gameOverLabel.position.y - 70)
        finalScoreLabel.zPosition = 1
        // gameOverPanel.addChild(finalScoreLabel)

        let highScoreLabel = SKLabelNode(fontNamed: "PressStart2P-Regular")
        highScoreLabel.text = "EN YÜKSEK: \(UserDefaults.standard.integer(forKey: "HighScore"))"
        highScoreLabel.fontSize = 14
        highScoreLabel.fontColor = .yellow // Sarı kalabilir, dikkat çeker
        highScoreLabel.position = CGPoint(x: 0, y: finalScoreLabel.position.y - 40)
        highScoreLabel.zPosition = 1
        // gameOverPanel.addChild(highScoreLabel)

        // 5. Butonlar
        let buttonWidth: CGFloat = panelWidth * 0.7
        let buttonHeight: CGFloat = 45
        let buttonFontSize: CGFloat = 14

        // Yeniden Başla Butonu
        let restartButtonBG = SKShapeNode(rectOf: CGSize(width: buttonWidth, height: buttonHeight), cornerRadius: panelCornerRadius)
        restartButtonBG.name = "restartButton" // Dokunma için ana node bu olsun
        restartButtonBG.fillColor = SKColor(red: 0.2, green: 0.25, blue: 0.4, alpha: 1.0) // Buton rengi
        restartButtonBG.strokeColor = SKColor.green.withAlphaComponent(0.8) // Neon kenarlık
        restartButtonBG.lineWidth = 1.5
        restartButtonBG.position = CGPoint(x: 0, y: highScoreLabel.position.y - 70)
        restartButtonBG.zPosition = 1
        // gameOverPanel.addChild(restartButtonBG)

        let restartButtonLabel = SKLabelNode(text: "Yeniden Başla") // Emoji + Metin
        restartButtonLabel.fontName = "PressStart2P-Regular"
        restartButtonLabel.fontSize = buttonFontSize
        restartButtonLabel.fontColor = .white
        restartButtonLabel.verticalAlignmentMode = .center
        restartButtonLabel.name = "restartButtonLabel" // Sadece label, dokunma BG üzerinden
        restartButtonLabel.zPosition = 1
        restartButtonBG.addChild(restartButtonLabel)

        // Ana Menü Butonu
        let menuButtonBG = SKShapeNode(rectOf: CGSize(width: buttonWidth, height: buttonHeight), cornerRadius: panelCornerRadius)
        menuButtonBG.name = "menuButton" // Dokunma için ana node bu olsun
        menuButtonBG.fillColor = SKColor(red: 0.4, green: 0.2, blue: 0.25, alpha: 1.0) // Farklı bir buton rengi
        menuButtonBG.strokeColor = SKColor.orange.withAlphaComponent(0.8) // Neon kenarlık
        menuButtonBG.lineWidth = 1.5
        menuButtonBG.position = CGPoint(x: 0, y: restartButtonBG.position.y - buttonHeight - 20)
        menuButtonBG.zPosition = 1
        // gameOverPanel.addChild(menuButtonBG)

        let menuButtonLabel = SKLabelNode(text: "Ana Menü")
        menuButtonLabel.fontName = "PressStart2P-Regular"
        menuButtonLabel.fontSize = buttonFontSize
        menuButtonLabel.fontColor = .white
        menuButtonLabel.verticalAlignmentMode = .center
        menuButtonLabel.name = "menuButtonLabel"
        menuButtonLabel.zPosition = 1
        menuButtonBG.addChild(menuButtonLabel)

        // 6. Panel ve İçerik Animasyonları
        let fadeInAction = SKAction.fadeIn(withDuration: 0.25)

        let scaleAction = SKAction.scale(to: 1.0, duration: 0.25)
        scaleAction.timingMode = .easeOut // timingMode'u burada ayarlayın

        let panelAppearAction = SKAction.group([
            fadeInAction,
            scaleAction
        ])

        gameOverPanel.run(panelAppearAction) { [weak self, gameOverLabel, shadowLabel, finalScoreLabel, highScoreLabel, restartButtonBG, menuButtonBG] in
            // Panel animasyonu bittikten sonra iç elemanları ekle ve anime et
            guard let self = self else { return }
            
            gameOverPanel.addChild(shadowLabel)
            gameOverPanel.addChild(gameOverLabel)
            gameOverPanel.addChild(finalScoreLabel)
            gameOverPanel.addChild(highScoreLabel)
            gameOverPanel.addChild(restartButtonBG)
            gameOverPanel.addChild(menuButtonBG)

            let fadeIn = SKAction.fadeIn(withDuration: 0.3)
            let popIn = SKAction.sequence([SKAction.scale(to: 1.1, duration: 0.1), SKAction.scale(to: 1.0, duration: 0.1)])
            let contentAppear = SKAction.group([fadeIn, popIn])
            
            let pulse = SKAction.sequence([SKAction.scale(to: 1.05, duration: 0.7), SKAction.scale(to: 1.0, duration: 0.7)])
            let repeatPulse = SKAction.repeatForever(pulse)

            // Başlık için özel animasyon (eskisi gibi veya yeni)
            shadowLabel.alpha = 0; shadowLabel.setScale(0.8)
            gameOverLabel.alpha = 0; gameOverLabel.setScale(0.8)
            shadowLabel.run(SKAction.group([contentAppear, repeatPulse]))
            gameOverLabel.run(SKAction.group([contentAppear, repeatPulse])) // Ana başlık da pulse yapsın

            // Diğer elemanlar için basit belirme
            let elementsToFade = [finalScoreLabel, highScoreLabel, restartButtonBG, menuButtonBG]
            var delay: TimeInterval = 0.2 // Başlıktan sonra başlasınlar
            for element in elementsToFade {
                element.alpha = 0
                element.run(SKAction.sequence([SKAction.wait(forDuration: delay), SKAction.fadeIn(withDuration: 0.3)]))
                delay += 0.1
            }
        }
    }

    // GameScene sınıfı içinde:
    func restartGame() {
        clearSavedGame()
        // Oyun sonu arayüzünün ana elemanlarını kaldır
        childNode(withName: "gameOverOverlay")?.removeFromParent()
        childNode(withName: "gameOverPanel")?.removeFromParent()
        // Not: Eğer "gameOverLabel", "restartButton", "menuButton" gibi elemanlar
        // bir önceki yapıda doğrudan sahneye eklenmişse ve artık panelin çocuğu değillerse,
        // onların da ayrıca isimleriyle kaldırılması gerekebilir.
        // Ancak son önerilen yapıda panelin kaldırılması yeterlidir.

        // Grid durumunu ve sprite'larını sıfırla (mevcut kodunuz)
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                gridState[row][col] = 0
                gridSpriteMap[row][col]?.removeFromParent()
                gridSpriteMap[row][col] = nil
            }
        }

        // Oyun sonu animasyonunda eklenen dolgu sprite'larını temizle (mevcut kodunuz)
        for sprite in gameOverFillerSprites {
            sprite.removeFromParent()
        }
        gameOverFillerSprites.removeAll()

        // Oyun değişkenlerini sıfırla (mevcut kodunuz)
        score = 0
        // scoreLabel'ın nil olup olmadığını kontrol etmek iyi bir pratiktir,
        // eğer sahne tam yüklenmeden bir restart olursa diye.
        if scoreLabel != nil {
            scoreLabel.text = "Skor: 0"
        }
        
        // Sonraki blokları temizle (mevcut kodunuz)
        for block in nextBlocks {
            block.removeFromParent()
        }
        nextBlocks.removeAll()
        
        // Diğer oyun durumlarını sıfırla (mevcut kodunuz)
        rotateUsed = false
        selectedNode = nil
        isDragging = false
        lastValidPosition = nil
        
        // Olası vurgulamaları da temizleyelim (önlem olarak)
        resetProspectiveHighlights()
        resetGridHighlight()

        // Oyunu yeniden başlatmak için gerekli fonksiyonları çağır (mevcut kodunuz)
        updateRotateButtonState()
        spawnNextBlocks() // Bu fonksiyon içinde checkGameOver çağrılabilir, dikkatli olunmalı.
                          // Ancak grid boşken checkGameOver sorun çıkarmamalı.
        updateBottomBlockStyles()
        // layoutPreview() // spawnNextBlocks içinde çağrılıyorsa gerek yok.
    }

    private func layoutPreview() {
           previewContainer.removeAllChildren()
           guard nextBlocks.count > 1 else { return }

           // Preview kutusu çiz
           let previewBox = SKShapeNode(rectOf: CGSize(width: 80, height: 80), cornerRadius: 14)
           previewBox.fillColor = SKColor.black.withAlphaComponent(0.34)
           previewBox.strokeColor = .white.withAlphaComponent(0.16)
           previewBox.lineWidth = 2
           previewBox.position = CGPoint(x: size.width - 60, y: 76)
           previewBox.zPosition = 300
           previewContainer.addChild(previewBox)

           // "NEXT" yazısı
           let nextLabel = SKLabelNode(fontNamed: "PressStart2P-Regular")
           nextLabel.text = "NEXT"
           nextLabel.fontSize = 16
           nextLabel.fontColor = .white.withAlphaComponent(0.9)
           nextLabel.position = CGPoint(x: previewBox.position.x, y: previewBox.position.y + 52)
           nextLabel.zPosition = 310
           previewContainer.addChild(nextLabel)

           // Sıradaki blok için yeni node oluştur (scale 1.0 ile)
           let blockNode = nextBlocks[1]
           guard let blockNodeCast = blockNode as? BlockNode else { return }
           let shape = blockNodeCast.blockShape
           let previewBlock = spawnBlock(from: shape, at: .zero, scale: 1.0)

           // Ortala
           let blockBox = previewBlock.calculateAccumulatedFrame()
           for c in previewBlock.children {
               c.position.x -= blockBox.midX
               c.position.y -= blockBox.midY
           }

           // Preview kutusuna tam sığacak şekilde scale hesapla
           let largestSide = max(blockBox.width, blockBox.height)
           let padding: CGFloat = 18
           let previewSize: CGFloat = 80
           let scale = (previewSize - padding) / largestSide
           previewBlock.setScale(scale)

           previewBlock.position = previewBox.position
           previewBlock.alpha = 1.0
           previewBlock.zPosition = 310
           previewContainer.addChild(previewBlock)
       }


       private func centerMini(_ node: SKNode, slot: CGFloat = 80) {
           let box = node.calculateAccumulatedFrame()
           for c in node.children {
               c.position.x -= box.midX
               c.position.y -= box.midY
           }
           let largestSide = max(box.width, box.height)
           let padding: CGFloat = 14
           let scale = (slot - padding) / largestSide
           node.setScale(min(scale, 1.0))
       }

       // GameScene sınıfı içinde:
       func checkAndClearLines() {
           var fullRows: [Int] = []
           var fullCols: [Int] = []
           
           for r in 0..<gridSize {
               if gridState[r].allSatisfy({ $0 == 1 }) { fullRows.append(r) }
           }
           for c in 0..<gridSize {
               if (0..<gridSize).allSatisfy({ r in gridState[r][c] == 1 }) { fullCols.append(c) }
           }

           let cellsToClear: [(row: Int, col: Int)] = fullRows.flatMap { row_idx in
                                                      (0..<gridSize).map { col_idx in (row_idx, col_idx) }
                                                  } +
                                                  fullCols.flatMap { col_idx in
                                                      (0..<gridSize).filter { row_idx in
                                                          !fullRows.contains(row_idx)
                                                      }.map { row_idx in (row_idx, col_idx) }
                                                  }

           let lineCount = fullRows.count + fullCols.count

           if lineCount > 0 {
                  if Settings.isSoundEnabled {
                      run(SKAction.playSoundFileNamed("explosion.wav", waitForCompletion: false))
                  }
                  comboCount += 1
                  // ...
              
               if comboCount >= 2 {
                   if Settings.isSoundEnabled {
                       run(SKAction.playSoundFileNamed("explosion.wav", waitForCompletion: false))
                   }
                   showComboEffect(level: comboCount) // Kombo efekti göster
                   
               }

               // --- YENİ PUANLAMA MANTIĞI ---
               var currentTurnScore = 0
               let basePointsPerLine = 100 // Temel hat başına puan

               // Aynı anda temizlenen hat sayısına göre bonus puanlama
               switch lineCount {
               case 1:
                   currentTurnScore = basePointsPerLine // 1 hat = 100
               case 2:
                   currentTurnScore = basePointsPerLine * 2 + 150 // 2 hat = 350
               case 3:
                   currentTurnScore = basePointsPerLine * 3 + 450 // 3 hat = 750
               case 4:
                   currentTurnScore = basePointsPerLine * 4 + 1000 // 4 hat = 1400 (Tetris!)
               default: // 4'ten fazla
                   currentTurnScore = basePointsPerLine * lineCount + (lineCount * 300)
               }
               
               // Kombo Çarpanı (ardışık temizlemeler için)
               var comboMultiplier: CGFloat = 1.0
               if comboCount >= 2 {
                   // Her kombo seviyesi için %50 ekstra puan
                   comboMultiplier = 1.0 + (CGFloat(comboCount - 1) * 0.5)
               }
               currentTurnScore = Int(CGFloat(currentTurnScore) * comboMultiplier)
               
               // Skoru animasyonlu güncelle
               animateScoreUpdate(to: score + currentTurnScore)
               // --- PUANLAMA MANTIĞI SONU ---
               
           } else {
               // Eğer hat temizlenmediyse komboyu sıfırla
               comboCount = 0
           }
           
           updateScoreLabel() // Etiketin anlık değerini günceller
           checkForLevelUp()
               

           // Sweep animasyonları
           for row_sweep in fullRows {
               let sweep = SKShapeNode(rectOf: CGSize(width: cellSize * CGFloat(gridSize), height: cellSize / 1.4))
               sweep.fillColor = .white
               sweep.alpha = 0.18
               sweep.position = CGPoint(x: size.width/2, y: gridOrigin.y + CGFloat(row_sweep) * cellSize + cellSize/2)
               sweep.zPosition = 101
               addChild(sweep)
               sweep.run(.sequence([
                   .fadeOut(withDuration: 0.19),
                   .removeFromParent()
               ]))
           }
           for col_sweep in fullCols {
               let sweep = SKShapeNode(rectOf: CGSize(width: cellSize / 1.4, height: cellSize * CGFloat(gridSize)))
               sweep.fillColor = .white
               sweep.alpha = 0.18
               sweep.position = CGPoint(x: gridOrigin.x + CGFloat(col_sweep) * cellSize + cellSize/2, y: size.height/2)
               sweep.zPosition = 101
               addChild(sweep)
               sweep.run(.sequence([
                   .fadeOut(withDuration: 0.19),
                   .removeFromParent()
               ]))
           }

           // Blokları temizleme
           for (row, col) in cellsToClear {
               gridState[row][col] = 0
               if let sprite = gridSpriteMap[row][col] {
                   let worldPosition = sprite.parent?.convert(sprite.position, to: self) ?? sprite.position
                   showBlockExplosion(
                       at: worldPosition,
                       color: sprite.fillColor,
                       parent: self
                   )
                   let scaleDown = SKAction.scale(to: 0.0, duration: 0.15)
                   let fadeOut = SKAction.fadeOut(withDuration: 0.15)
                   let sparkle = SKAction.sequence([
                       SKAction.group([scaleDown, fadeOut]),
                       SKAction.removeFromParent()
                   ])
                   sprite.run(sparkle)
                   gridSpriteMap[row][col] = nil
               }
           }
           // En yüksek skor güncelleme mantığı updateScoreLabel() fonksiyonuna taşındığı için buradan kaldırıldı.
       }

       // GameScene.swift -> Mevcut showComboEffect fonksiyonunu silip yerine bunu yapıştır.

       func showComboEffect(level: Int) {
           let labelText = "✨ \(level)x KOMBO! ✨"

           // 1. Neon ana renkler ve gölgeler
           let mainNeon = SKColor(red: 0.98, green: 1, blue: 0.36, alpha: 1)
           let neonGlow1 = SKColor(red: 0.4, green: 1, blue: 0.9, alpha: 0.95)
           let neonGlow2 = SKColor(red: 0.98, green: 0.29, blue: 1, alpha: 0.7)
           let hardShadow = SKColor.black.withAlphaComponent(0.92)
           
           let center = CGPoint(x: size.width / 2, y: size.height / 2 + 22)
           
           // --- Multi Glow Katmanı: Soft, büyük daireler ---
           func glowCircle(radius: CGFloat, color: SKColor, alpha: CGFloat, z: CGFloat) -> SKShapeNode {
               let n = SKShapeNode(circleOfRadius: radius)
               n.position = center
               n.fillColor = color.withAlphaComponent(alpha)
               n.strokeColor = color.withAlphaComponent(alpha * 0.9)
               n.lineWidth = 4
               n.glowWidth = 16
               n.zPosition = z
               n.alpha = 0
               return n
           }
           
           let bgGlowBig = glowCircle(radius: 145, color: neonGlow1, alpha: 0.24, z: 201)
           let bgGlowMed = glowCircle(radius: 95, color: neonGlow2, alpha: 0.18, z: 202)
           let bgGlowSmall = glowCircle(radius: 50, color: mainNeon, alpha: 0.16, z: 203)
           addChild(bgGlowBig); addChild(bgGlowMed); addChild(bgGlowSmall)
           [bgGlowBig, bgGlowMed, bgGlowSmall].forEach { node in
               node.run(.sequence([
                   .group([
                       .fadeAlpha(to: 1.0, duration: 0.11),
                       .scale(to: 1.5, duration: 0.18)
                   ]),
                   .wait(forDuration: 0.16 + 0.10 * Double(level)),
                   .fadeOut(withDuration: 0.22),
                   .removeFromParent()
               ]))
           }
           
           // --- Ana Kombo Label, çok katmanlı neon gölgeyle ---
           let font = "PressStart2P-Regular"
           let fontSize = 18 + CGFloat(level * 3)
           let posY: CGFloat = center.y
           let posX: CGFloat = center.x

           // Ana yazının arkası için katmanlı glow efektleri (arka arkaya koyuyoruz)
           let outerGlow = SKLabelNode(fontNamed: font)
           outerGlow.text = labelText
           outerGlow.fontSize = fontSize
           outerGlow.fontColor = neonGlow2
           outerGlow.position = CGPoint(x: posX, y: posY)
           outerGlow.zPosition = 210
           outerGlow.alpha = 0
           outerGlow.setScale(0.78)
           outerGlow.blendMode = .add // Daha güçlü glow için

           let midGlow = SKLabelNode(fontNamed: font)
           midGlow.text = labelText
           midGlow.fontSize = fontSize
           midGlow.fontColor = neonGlow1
           midGlow.position = CGPoint(x: posX, y: posY)
           midGlow.zPosition = 211
           midGlow.alpha = 0
           midGlow.setScale(0.83)
           midGlow.blendMode = .add

           let mainLabel = SKLabelNode(fontNamed: font)
           mainLabel.text = labelText
           mainLabel.fontSize = fontSize
           mainLabel.fontColor = mainNeon
           mainLabel.position = CGPoint(x: posX, y: posY)
           mainLabel.zPosition = 213
           mainLabel.alpha = 0
           mainLabel.setScale(0.7)

           let shadowLabel = SKLabelNode(fontNamed: font)
           shadowLabel.text = labelText
           shadowLabel.fontSize = fontSize
           shadowLabel.fontColor = hardShadow
           shadowLabel.position = CGPoint(x: posX + 4, y: posY - 4)
           shadowLabel.zPosition = 209
           shadowLabel.alpha = 0
           shadowLabel.setScale(0.7)
           
           [outerGlow, midGlow, shadowLabel, mainLabel].forEach { addChild($0) }

           // --- Animasyonlar: Retro Arcade Stil ---
           let fadeIn = SKAction.fadeIn(withDuration: 0.11)
           let scaleUp = SKAction.scale(to: 1.22, duration: 0.20)
           scaleUp.timingMode = .easeOut
           let wait = SKAction.wait(forDuration: 1.0 + Double(level) * 0.09)
           let scaleDown = SKAction.scale(to: 0.9, duration: 0.21)
           scaleDown.timingMode = .easeInEaseOut
           let fadeOut = SKAction.fadeOut(withDuration: 0.19)
           let remove = SKAction.removeFromParent()
           let groupIn = SKAction.group([fadeIn, scaleUp])
           let groupOut = SKAction.group([fadeOut, scaleDown])
           let textSequence = SKAction.sequence([groupIn, wait, groupOut, remove])

           // Arka gölgeleri biraz daha büyüterek “glow” efekti veriyoruz
           outerGlow.run(textSequence)
           midGlow.run(textSequence)
           shadowLabel.run(textSequence)
           mainLabel.run(textSequence)
           
           // --- Parçacık + Sarsıntı ---
           if let sparkle = SKEmitterNode(fileNamed: "ComboSparkle.sks") {
               sparkle.position = center
               sparkle.zPosition = 255
               addChild(sparkle)
               sparkle.run(.sequence([
                   .wait(forDuration: 1.0 + Double(level) * 0.08),
                   .fadeOut(withDuration: 0.19),
                   .removeFromParent()
               ]))
           }
           // Daha güçlü bir ekran sarsıntısı
           let shakeAmount: CGFloat = 9 + CGFloat(level) * 1.2
           let shake = SKAction.sequence([
               SKAction.moveBy(x: shakeAmount, y: 0, duration: 0.022),
               SKAction.moveBy(x: -shakeAmount*2, y: 0, duration: 0.024),
               SKAction.moveBy(x: shakeAmount*2, y: 0, duration: 0.025),
               SKAction.moveBy(x: -shakeAmount, y: 0, duration: 0.022),
               SKAction.moveBy(x: 0, y: 0, duration: 0.01)
           ])
           self.run(shake)
       }


       // GameScene sınıfı içinde:
       func checkGameOver() {
           guard let currentBlock = nextBlocks.first else { return }

           if canPlaceBlock(currentBlock, considerRotation: false) {
               return // Oyun devam edebilir
           }

           // Blok olduğu gibi yerleştirilemiyor. Döndürme hakkı var mı ve işe yarar mı?
           if !rotateUsed {
               if canPlaceBlock(currentBlock, considerRotation: true) {
                   return // Döndürerek yerleşebilir, oyun devam
               } else {
                   // Döndürülse bile yerleşemiyor VE döndürme hakkı henüz kullanılmamış.
                   // Bu durumda oyun biter.
                   startGameOverGridFillAnimation() // << DEĞİŞİKLİK: showGameOver() yerine bu çağrılacak
                   return
               }
           } else { // Döndürme hakkı zaten kullanılmış
               // Blok olduğu gibi de yerleştirilemiyor, döndürme hakkı da yok. Oyun biter.
               startGameOverGridFillAnimation() // << DEĞİŞİKLİK: showGameOver() yerine bu çağrılacak
               return
           }
       }
       
       // GameScene sınıfı içinde:
       // GameScene sınıfı içinde:
       func startGameOverGridFillAnimation() {
           // Oyuncu etkileşimini engellemek için ek kontroller (genellikle gerekmez)
           // self.isUserInteractionEnabled = false

           var emptyCells: [GridCoordinate] = []
           for r in 0..<gridSize {
               for c in 0..<gridSize {
                   if gridState[r][c] == 0 {
                       emptyCells.append(GridCoordinate(row: r, col: c))
                   }
               }
           }

           if emptyCells.isEmpty {
               self.showGameOver()
               return
           }

           emptyCells.shuffle() // Rastgele dolma sırası için

           var actions: [SKAction] = []
           // Her bir dolan blok parçası için renkleri rastgele seçelim veya sabit bir "oyun sonu" rengi belirleyelim.
           // Rastgele renkler daha canlı bir "kaotik dolma" efekti verebilir.
           
           let delayBetweenFills: TimeInterval = 0.03
           let cellAppearDuration: TimeInterval = 0.5 // Her parçanın belirme süresi
           let cellPopDuration: TimeInterval = 0.05   // Pop efektinin her adımı

           for cellCoord in emptyCells {
               let waitAction = SKAction.wait(forDuration: delayBetweenFills)
               
               let fillCellAction = SKAction.run { [weak self] in
                   guard let self = self else { return }

                   let tempShapeData = self.generateRandomShape()
                   let baseFillColor = tempShapeData.color

                   let blockPart = SKShapeNode(rectOf: CGSize(width: cellSize - 2, height: cellSize - 2), cornerRadius: 3)
                   
                   // --- ÖNEMLİ DÜZELTME/KONTROL NOKTASI ---
                   // Blok parçasının ana dolgu rengini burada AÇIKÇA ayarlayın.
                   // addBevelEffect, bu rengi temel alarak kenarlıkların ve gölgelerin rengini belirler,
                   // ancak ana karenin merkez dolgusunu KENDİSİ AYARLAMAZ.
                   blockPart.fillColor = baseFillColor
                   // --- DÜZELTME/KONTROL NOKTASI SONU ---
                   
                   self.addBevelEffect(to: blockPart, baseColor: baseFillColor, fullCellSize: cellSize)
                   
                   blockPart.position = self.gridPositionToPoint(row: cellCoord.row, col: cellCoord.col)
                   blockPart.zPosition = 1 // Diğer bloklarla benzer bir zPozisyonu
                   
                   blockPart.setScale(0.1)
                   blockPart.alpha = 0.0
                   
                   self.addChild(blockPart)
                   self.gameOverFillerSprites.append(blockPart)

                   let appearEffect = SKAction.group([
                       SKAction.scale(to: 1.0, duration: cellAppearDuration),
                       SKAction.fadeAlpha(to: 1.0, duration: cellAppearDuration)
                   ])
                   let popEffect = SKAction.sequence([
                       SKAction.scale(to: 1.15, duration: cellPopDuration),
                       SKAction.scale(to: 1.0, duration: cellPopDuration)
                   ])
                   blockPart.run(SKAction.sequence([appearEffect, popEffect]))
               }
               actions.append(waitAction)
               actions.append(fillCellAction)
           }

           let finalWait = SKAction.wait(forDuration: 0.75) // Grid dolduktan sonra biraz daha bekle
           let showGameOverScreenAction = SKAction.run { [weak self] in
               self?.showGameOver()
           }
           actions.append(finalWait)
           actions.append(showGameOverScreenAction)

           self.run(SKAction.sequence(actions))
       }

       func canPlaceBlock(_ block: SKNode, considerRotation: Bool) -> Bool {
           let originalPositions = block.children.compactMap { ($0 as? SKShapeNode)?.position }
           guard originalPositions.count == block.children.count else { return false }
           let minX = originalPositions.map { $0.x }.min() ?? 0
           let minY = originalPositions.map { $0.y }.min() ?? 0
           let shapeOffsets = originalPositions.map {
               (Int(round(($0.x - minX) / cellSize)), Int(round(($0.y - minY) / cellSize)))
           }
           if canPlaceShapeAnywhere(shapeOffsets) { return true }
           if considerRotation {
               let rotatedOffsets = shapeOffsets.map { (x, y) in (-y, x) }
               if canPlaceShapeAnywhere(rotatedOffsets) { return true }
           }
           return false
       }

       func canPlaceShapeAnywhere(_ offsets: [(Int, Int)]) -> Bool {
           for row in 0..<gridSize {
               for col in 0..<gridSize {
                   let positions = offsets.map { (row + $0.1, col + $0.0) }
                   if positions.allSatisfy({ $0.0 >= 0 && $0.0 < gridSize && $0.1 >= 0 && $0.1 < gridSize }) &&
                       positions.allSatisfy({ gridState[$0.0][$0.1] == 0 }) {
                       return true
                   }
               }
           }
           return false
       }

       func showBlockExplosion(at position: CGPoint, color: SKColor, parent: SKNode) {
           let particle = SKEmitterNode()
           particle.particleTexture = SKTexture(imageNamed: "spark")
           particle.particleColor = color
           particle.particleColorBlendFactor = 1.0
           particle.numParticlesToEmit = 32
           particle.particleBirthRate = 1500
           particle.particleLifetime = 0.45
           particle.particleLifetimeRange = 0.2
           particle.particleAlpha = 1.0
           particle.particleAlphaRange = 0.3
           particle.particleAlphaSpeed = -2.0
           particle.particleScale = 0.5
           particle.particleScaleRange = 0.22
           particle.particleScaleSpeed = -0.45
           particle.emissionAngleRange = .pi * 2
           particle.particleSpeed = 270
           particle.particleSpeedRange = 120
           particle.position = position
           particle.zPosition = 100
           parent.addChild(particle)
           particle.run(SKAction.sequence([
               SKAction.wait(forDuration: 0.8),
               SKAction.removeFromParent()
           ]))
           let outerRing = SKShapeNode(circleOfRadius: 35)
           outerRing.position = position
           outerRing.fillColor = .clear
           outerRing.strokeColor = color.withAlphaComponent(0.55)
           outerRing.lineWidth = 10
           outerRing.alpha = 0.5
           outerRing.zPosition = 99
           parent.addChild(outerRing)
           outerRing.run(.sequence([
               .group([
                   .scale(to: 2.4, duration: 0.25),
                   .fadeOut(withDuration: 0.25)
               ]),
               .removeFromParent()
           ]))
           if let scene = parent as? SKScene {
               let amount: CGFloat = 8
               let shake = SKAction.sequence([
                   SKAction.moveBy(x: amount, y: 0, duration: 0.03),
                   SKAction.moveBy(x: -amount*2, y: 0, duration: 0.03),
                   SKAction.moveBy(x: amount*2, y: 0, duration: 0.03),
                   SKAction.moveBy(x: -amount, y: 0, duration: 0.03),
                   SKAction.moveBy(x: 0, y: 0, duration: 0.01)
               ])
               scene.run(shake)
           }
       }

       // GameScene sınıfı içinde:
       func clearAreaAround(row: Int, col: Int) {
           let rows = (row-1)...(row+1)
           let cols = (col-1)...(col+1)
           var blocksClearedByBomb = 0 // Bomba ile temizlenen blok sayısı

           for r in rows {
               for c in cols {
                   if r >= 0, r < gridSize, c >= 0, c < gridSize, gridState[r][c] == 1 {
                       let sprite = gridSpriteMap[r][c]
                       let worldPosition = sprite?.parent?.convert(sprite!.position, to: self) ?? gridPositionToPoint(row: r, col: c) // fallback
                       showBlockExplosion(at: worldPosition, color: sprite?.fillColor ?? .white, parent: self)
                       sprite?.run(SKAction.sequence([.scale(to: 0.0, duration: 0.14), .fadeOut(withDuration: 0.14), .removeFromParent()]))
                       gridState[r][c] = 0
                       gridSpriteMap[r][c] = nil
                       blocksClearedByBomb += 1 // Sayacı artır
                   }
               }
           }

           if blocksClearedByBomb > 0 {
               score += blocksClearedByBomb * pointsPerBlockFromSpecial
               animateScoreUpdate(to: score)
               updateScoreLabel()
               checkForLevelUp() // <-- BU SATIRI EKLEYİN// Skor etiketini güncelle
               // İsteğe bağlı: Bomba patlaması için küçük bir "puan kazandın" efekti gösterilebilir.
               // Kombo sayacını burada sıfırlamıyoruz, çünkü checkAndClearLines bunu yönetecek.
           }
       }

       // GameScene sınıfı içinde:
       func clearSameColorLines(row: Int, col: Int) {
           // Gökkuşağı bloğunun üzerine konduğu hücre boşsa, clearSameColorLines bir şey yapmaz.
           // Eğer dolu bir hücreye konduysa, o hücredeki sprite'ın rengini alır.
           // Bu mantık, vurgulama (highlight) ile tutarlı olmalı.
           guard let spriteLandedOn = gridSpriteMap[row][col] else { return }
           let colorToClear = spriteLandedOn.fillColor
           var blocksClearedByRainbow = 0 // Gökkuşağı ile temizlenen blok sayısı

           for r_idx in 0..<gridSize {
               for c_idx in 0..<gridSize {
                   // SKColor karşılaştırması için isApproximatelyEqualTo kullandığınızdan emin olun.
                   if let s = gridSpriteMap[r_idx][c_idx], s.fillColor.isApproximatelyEqualTo(colorToClear) {
                       let worldPosition = s.parent?.convert(s.position, to: self) ?? gridPositionToPoint(row: r_idx, col: c_idx)
                       showBlockExplosion(at: worldPosition, color: s.fillColor, parent: self)
                       s.run(SKAction.sequence([.scale(to: 0.0, duration: 0.14), .fadeOut(withDuration: 0.14), .removeFromParent()]))
                       gridState[r_idx][c_idx] = 0
                       gridSpriteMap[r_idx][c_idx] = nil
                       blocksClearedByRainbow += 1 // Sayacı artır
                   }
               }
           }

           if blocksClearedByRainbow > 0 {
               score += blocksClearedByRainbow * pointsPerBlockFromSpecial
               animateScoreUpdate(to: score)
               updateScoreLabel()
               checkForLevelUp() // <-- BU SATIRI EKLEYİN// Skor etiketini güncelle
           }
       }

       // BLOK YARATMA (Emoji eklenmiş)
       func spawnBlock(from shape: BlockShape, at position: CGPoint, scale: CGFloat = 1.0) -> BlockNode {
           let blockNode = BlockNode(blockShape: shape)
           blockNode.name = "draggable"
           for (index, cell) in shape.cells.enumerated() {
               // Orijinal kare oluşturma: Köşe yuvarlamasını azaltarak daha keskin yapalım.
               let square = SKShapeNode(rectOf: CGSize(width: cellSize - 2, height: cellSize - 2), cornerRadius: 3) // Daha keskin köşe
               square.fillColor = shape.color // Ana dolgu rengi

               // Eski stroke ve glow'u kaldırın:
               // square.strokeColor = .white.withAlphaComponent(0.27)
               // square.lineWidth = 2
               // let glow = SKShapeNode(rectOf: CGSize(width: cellSize, height: cellSize), cornerRadius: 9)
               // glow.fillColor = .white
               // glow.alpha = 0.07
               // glow.zPosition = -1
               // square.addChild(glow) // Glow'u kaldırıyoruz, pixel art tarzına uymayabilir.

               // Yeni eğim efektini ekleyin:
               addBevelEffect(to: square, baseColor: shape.color, fullCellSize: cellSize)

               // Emoji mantığı aynı kalır, 'square' SKShapeNode'una eklenir.
               // Emoji'nin boyutu ve zPosition'ı kenarların üzerinde kalacak şekilde ayarlanabilir.
               if index == 0 {
                   let emojiContainerNode = square // Emojiyi doğrudan square'e ekleyebiliriz
                   if shape.type == .bomb {
                       let bombLabel = SKLabelNode(text: "💣")
                       bombLabel.fontSize = (cellSize - 2) * 0.55 // Boyutu biraz ayarladım
                       bombLabel.fontName = "AppleColorEmoji" // Fontu belirtmek iyi olabilir
                       bombLabel.verticalAlignmentMode = .center
                       bombLabel.horizontalAlignmentMode = .center
                       bombLabel.zPosition = 5 // Kenarların (zPosition 1) ve ana dolgunun üzerinde
                       emojiContainerNode.addChild(bombLabel)
                   } else if shape.type == .rainbow {
                       let rainbowLabel = SKLabelNode(text: "🌈")
                       rainbowLabel.fontSize = (cellSize - 2) * 0.55
                       rainbowLabel.fontName = "AppleColorEmoji"
                       rainbowLabel.verticalAlignmentMode = .center
                       rainbowLabel.horizontalAlignmentMode = .center
                       rainbowLabel.zPosition = 5
                       emojiContainerNode.addChild(rainbowLabel)
                   }
               }

               square.position = CGPoint(
                   x: CGFloat(cell.0) * cellSize,
                   y: CGFloat(cell.1) * cellSize
               )
               blockNode.addChild(square)
           }

           // Bloğun merkezini ayarlama mantığı aynı kalır:
           let box = blockNode.calculateAccumulatedFrame()
           let center = CGPoint(x: box.midX, y: box.midY)
           for s in blockNode.children {
               s.position.x -= center.x
               s.position.y -= center.y
           }

           blockNode.position = position
           blockNode.setScale(scale) // Ölçeklemeyi de ekledim, eğer kullanıyorsanız.
           return blockNode
       }
       // GameScene sınıfı içinde:
       func addBevelEffect(to mainSquare: SKShapeNode, baseColor: SKColor, fullCellSize: CGFloat) {
           let edgeThickness: CGFloat = max(1.5, fullCellSize * 0.12)
           let lighterColor = baseColor.lighter(by: 0.22)
           let darkerColor = baseColor.darker(by: 0.28)
           let squareInnerSize = mainSquare.frame.size

           let topEdge = SKShapeNode(rectOf: CGSize(width: squareInnerSize.width, height: edgeThickness))
           topEdge.fillColor = lighterColor
           topEdge.strokeColor = lighterColor
           topEdge.isAntialiased = false
           topEdge.position = CGPoint(x: 0, y: squareInnerSize.height/2 - edgeThickness/2)
           topEdge.zPosition = 1
           topEdge.name = "bevel_top" // << YENİ İSİM
           mainSquare.addChild(topEdge)

           let leftEdge = SKShapeNode(rectOf: CGSize(width: edgeThickness, height: squareInnerSize.height))
           leftEdge.fillColor = lighterColor
           leftEdge.strokeColor = lighterColor
           leftEdge.isAntialiased = false
           leftEdge.position = CGPoint(x: -squareInnerSize.width/2 + edgeThickness/2, y: 0)
           leftEdge.zPosition = 1
           leftEdge.name = "bevel_left" // << YENİ İSİM
           mainSquare.addChild(leftEdge)

           let bottomEdge = SKShapeNode(rectOf: CGSize(width: squareInnerSize.width, height: edgeThickness))
           bottomEdge.fillColor = darkerColor
           bottomEdge.strokeColor = darkerColor
           bottomEdge.isAntialiased = false
           bottomEdge.position = CGPoint(x: 0, y: -squareInnerSize.height/2 + edgeThickness/2)
           bottomEdge.zPosition = 1
           bottomEdge.name = "bevel_bottom" // << YENİ İSİM
           mainSquare.addChild(bottomEdge)

           let rightEdge = SKShapeNode(rectOf: CGSize(width: edgeThickness, height: squareInnerSize.height))
           rightEdge.fillColor = darkerColor
           rightEdge.strokeColor = darkerColor
           rightEdge.isAntialiased = false
           rightEdge.position = CGPoint(x: squareInnerSize.width/2 - edgeThickness/2, y: 0)
           rightEdge.zPosition = 1
           rightEdge.name = "bevel_right" // << YENİ İSİM
           mainSquare.addChild(rightEdge)

           mainSquare.strokeColor = baseColor.darker(by: 0.5)
           mainSquare.lineWidth = 0.5
           mainSquare.isAntialiased = false
       }
       
       // GameScene sınıfı içinde:
       func updateBlockPartAppearance(spriteNode: SKShapeNode, newBaseColor: SKColor) {
           // Ana sprite'ın dolgu rengini güncelle
           spriteNode.fillColor = newBaseColor

           // Yeni ana renge göre açık ve koyu kenar renklerini hesapla
           let lighterBevelColor = newBaseColor.lighter(by: 0.22)
           let darkerBevelColor = newBaseColor.darker(by: 0.28)

           // İsimleriyle kenar node'larını bul ve renklerini güncelle
           if let topBevel = spriteNode.childNode(withName: "bevel_top") as? SKShapeNode {
               topBevel.fillColor = lighterBevelColor
               topBevel.strokeColor = lighterBevelColor // Kenarların stroke'u da dolguyla aynı olmalı
           }
           if let leftBevel = spriteNode.childNode(withName: "bevel_left") as? SKShapeNode {
               leftBevel.fillColor = lighterBevelColor
               leftBevel.strokeColor = lighterBevelColor
           }
           if let bottomBevel = spriteNode.childNode(withName: "bevel_bottom") as? SKShapeNode {
               bottomBevel.fillColor = darkerBevelColor
               bottomBevel.strokeColor = darkerBevelColor
           }
           if let rightBevel = spriteNode.childNode(withName: "bevel_right") as? SKShapeNode {
               rightBevel.fillColor = darkerBevelColor
               rightBevel.strokeColor = darkerBevelColor
           }

           // Ana sprite'ın kendi kenar çizgisini de yeni ana renge göre güncelle
           spriteNode.strokeColor = newBaseColor.darker(by: 0.5)
           // spriteNode.lineWidth = 0.5 // Bu zaten addBevelEffect'te ayarlanmıştı, değişmesine gerek yok.
       }
       func updateBottomBlockStyles() {
           for (i, block) in nextBlocks.enumerated() {
               if i == 0 {
                   block.alpha = 1.0
                   block.run(SKAction.fadeAlpha(to: 1.0, duration: 0.1))
               } else {
                   block.alpha = 0.75
                   block.run(SKAction.fadeAlpha(to: 0.75, duration: 0.1))
               }
           }
       }
       
       func createPixelCell(size: CGSize, baseColor: SKColor) -> SKNode {
           let cellNode = SKNode()
           // Kenar kalınlığını cellSize'a göre orantılı yapalım, örneğin %10'u kadar.
           // Ve en az 1 pixel (veya puan) olmasını sağlayalım.
           let edgeRatio: CGFloat = 0.12 // Kenar kalınlığı oranı, %12 iyi bir başlangıç olabilir.
           let cornerRadiusRatio: CGFloat = 0.08 // Köşe yuvarlama oranı

           let edgeThickness: CGFloat = max(1.5, size.width * edgeRatio) // Kalınlık en az 1.5 puan
           let cellCornerRadius: CGFloat = max(1, size.width * cornerRadiusRatio)


           // Referans oyunda ışık genellikle sol üstten gelir gibi duruyor.
           // Bu yüzden üst ve sol kenarlar daha açık, alt ve sağ kenarlar daha koyu olacak.
           let lighterColor = baseColor.lighter(by: 0.20)
           let darkerColor = baseColor.darker(by: 0.25)

           // Ana Dolgu (kenarlar için biraz küçültülmüş)
           // Kenarların her biri 'edgeThickness' kadar olduğu için, ana dolguyu buna göre ayarlamalıyız.
           // Ancak kenarlar birbirini örteceği için tam olarak 2*edgeThickness küçültmek yerine
           // kenarların nasıl yerleşeceğine göre ayarlama yapmak daha iyi.
           // Basit bir yaklaşım: Ana dolgu tam boyutta olsun, kenarlar üzerine binsin.
           // Veya ana dolguyu kenar kalınlığı kadar küçültüp, kenarları dışa doğru yerleştirebiliriz.
           // Referans oyundaki gibi bir görünüm için, ana dolgu ortada ve kenarlar onu çerçeveliyor.

           let mainRect = SKShapeNode(rectOf: size, cornerRadius: cellCornerRadius)
           mainRect.fillColor = baseColor
           mainRect.strokeColor = baseColor // Veya çok ince bir koyu çizgi: baseColor.darker(by: 0.4)
           mainRect.lineWidth = 1 // Eğer strokeColor kullanılıyorsa
           // mainRect.isAntialiased = false // Pixel art için anti-aliasing kapatılabilir
           cellNode.addChild(mainRect)

           // Üst Kenar (Açık Renk)
           let topEdgePath = UIBezierPath()
           topEdgePath.move(to: CGPoint(x: -size.width/2, y: size.height/2))
           topEdgePath.addLine(to: CGPoint(x: size.width/2, y: size.height/2))
           topEdgePath.addLine(to: CGPoint(x: size.width/2 - edgeThickness, y: size.height/2 - edgeThickness))
           topEdgePath.addLine(to: CGPoint(x: -size.width/2 + edgeThickness, y: size.height/2 - edgeThickness))
           topEdgePath.close()
           let topEdge = SKShapeNode(path: topEdgePath.cgPath)
           topEdge.fillColor = lighterColor
           topEdge.strokeColor = lighterColor
           // topEdge.isAntialiased = false
           cellNode.addChild(topEdge)

           // Sol Kenar (Açık Renk)
           let leftEdgePath = UIBezierPath()
           leftEdgePath.move(to: CGPoint(x: -size.width/2, y: size.height/2))
           leftEdgePath.addLine(to: CGPoint(x: -size.width/2, y: -size.height/2))
           leftEdgePath.addLine(to: CGPoint(x: -size.width/2 + edgeThickness, y: -size.height/2 + edgeThickness))
           leftEdgePath.addLine(to: CGPoint(x: -size.width/2 + edgeThickness, y: size.height/2 - edgeThickness))
           leftEdgePath.close()
           let leftEdge = SKShapeNode(path: leftEdgePath.cgPath)
           leftEdge.fillColor = lighterColor
           leftEdge.strokeColor = lighterColor
           // leftEdge.isAntialiased = false
           cellNode.addChild(leftEdge)

           // Alt Kenar (Koyu Renk)
           let bottomEdgePath = UIBezierPath()
           bottomEdgePath.move(to: CGPoint(x: -size.width/2, y: -size.height/2))
           bottomEdgePath.addLine(to: CGPoint(x: size.width/2, y: -size.height/2))
           bottomEdgePath.addLine(to: CGPoint(x: size.width/2 - edgeThickness, y: -size.height/2 + edgeThickness))
           bottomEdgePath.addLine(to: CGPoint(x: -size.width/2 + edgeThickness, y: -size.height/2 + edgeThickness))
           bottomEdgePath.close()
           let bottomEdge = SKShapeNode(path: bottomEdgePath.cgPath)
           bottomEdge.fillColor = darkerColor
           bottomEdge.strokeColor = darkerColor
           // bottomEdge.isAntialiased = false
           cellNode.addChild(bottomEdge)

           // Sağ Kenar (Koyu Renk)
           let rightEdgePath = UIBezierPath()
           rightEdgePath.move(to: CGPoint(x: size.width/2, y: size.height/2))
           rightEdgePath.addLine(to: CGPoint(x: size.width/2, y: -size.height/2))
           rightEdgePath.addLine(to: CGPoint(x: size.width/2 - edgeThickness, y: -size.height/2 + edgeThickness))
           rightEdgePath.addLine(to: CGPoint(x: size.width/2 - edgeThickness, y: size.height/2 - edgeThickness))
           rightEdgePath.close()
           let rightEdge = SKShapeNode(path: rightEdgePath.cgPath)
           rightEdge.fillColor = darkerColor
           rightEdge.strokeColor = darkerColor
           // rightEdge.isAntialiased = false
           cellNode.addChild(rightEdge)
           
           // Köşe yuvarlaması olan bir ana dikdörtgen kullandığımız için,
           // kenarlar bu yuvarlamayı takip etmeyebilir. Daha keskin köşeler için
           // SKShapeNode(rectOf:...) kullanıp pozisyonlamak veya path'leri ona göre ayarlamak gerekebilir.
           // Şimdilik bu path'ler yamuk şeklinde kenarlar oluşturacaktır.
           // Daha basit bir yaklaşım, ana dikdörtgenin üzerine tam kaplayan ama hafif offsetli kenarlar koymaktır.

           return cellNode
       }
       // GameScene.swift içine, diğer fonksiyonların yanına ekleyin

       func checkForLevelUp() {
           if score >= scoreForNextLevel {
               // Seviye atla
               currentLevel += 1
               
               // Bir sonraki seviye hedefini artır (her seviyede 2000 puan eklensin)
               scoreForNextLevel += 2000
               
               // Oyuncuya görsel bir bildirim göster
               showLevelUpEffect()
               
               // Etiketi güncelle
               if levelLabel != nil { // Nil kontrolü
                    levelLabel.text = "Level: \(currentLevel)"
               }
           }
       }

       func showLevelUpEffect() {
        
           // Projenize "level_up.wav" adında bir ses dosyası eklerseniz bu çalışır.
           // self.run(SKAction.playSoundFileNamed("level_up.wav", waitForCompletion: false))
       }
       // GameScene.swift içine eklenecek fonksiyon

       func animateScoreUpdate(to newScore: Int) {
           // Animasyonun başlayacağı mevcut skoru sakla
           let oldScore = self.score
           
           // Asıl skor değişkenini hemen güncelle
           self.score = newScore
           
           // Skor etiketinde sayma efekti yaratacak animasyon
           let duration: TimeInterval = 0.4
           let scoreUpdateAction = SKAction.customAction(withDuration: duration) { node, elapsedTime in
               let progress = elapsedTime / CGFloat(duration)
               let currentDisplayScore = oldScore + Int(CGFloat(newScore - oldScore) * progress)
               // SKLabelNode'u güvenle cast et
               if let labelNode = node as? SKLabelNode {
                   labelNode.text = "Skor: \(currentDisplayScore)"
               }
           }
           
           // Skor etiketine dikkat çekmek için "patlama/büyüme" efekti
           let popAction = SKAction.sequence([
               .scale(to: 1.25, duration: 0.1),
               .scale(to: 1.0, duration: 0.1)
           ])
           
           // Animasyonları başlat
           scoreLabel.run(popAction)
           scoreLabel.run(scoreUpdateAction)

           // En yüksek skoru da kontrol edip güncelleyelim
           let currentHighScore = UserDefaults.standard.integer(forKey: "HighScore")
           if newScore > currentHighScore {
               UserDefaults.standard.set(newScore, forKey: "HighScore")
               if let panel = topPanel, let highScoreLabel = panel.childNode(withName: "highScoreLabel") as? SKLabelNode {
                   highScoreLabel.text = "En Yüksek: \(newScore)"
               }
           }
           // GameScene.swift içine yeni bir yardımcı fonksiyon olarak ekleyin.

          
       }
       // GameScene.swift -> Mevcut saveGameState ve loadGameState fonksiyonlarını SİL ve bunları YAPIŞTIR.

       @objc func saveGameState() {
           var savedGrid: [[String: Any]] = []
           for r in 0..<gridSize {
               for c in 0..<gridSize {
                   if let sprite = gridSpriteMap[r][c] {
                       var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
                       sprite.fillColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
                       
                       // Düzeltilmiş Tip Belirleme: Sprite'ın içindeki emojiyi kontrol et.
                       var blockTypeString = "normal"
                       if let label = sprite.children.first(where: { $0 is SKLabelNode }) as? SKLabelNode {
                           if label.text == "💣" {
                               blockTypeString = "bomb"
                           } else if label.text == "🌈" {
                               blockTypeString = "rainbow"
                           }
                       }

                       let cellData: [String: Any] = [
                           "row": r, "col": c, "color": [red, green, blue, alpha], "type": blockTypeString
                       ]
                       savedGrid.append(cellData)
                   }
               }
           }
           
           var savedNextBlocks: [[String: Any]] = []
           for block in nextBlocks {
               if let blockNode = block as? BlockNode {
                   let shape = blockNode.blockShape
                   var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
                   shape.color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
                   let blockData: [String: Any] = ["cells": shape.cells.map { [$0.0, $0.1] }, "color": [red, green, blue, alpha], "type": shape.type == .bomb ? "bomb" : (shape.type == .rainbow ? "rainbow" : "normal")]
                   savedNextBlocks.append(blockData)
               }
           }
           let gameState: [String: Any] = ["gridState": savedGrid, "nextBlocks": savedNextBlocks, "score": score, "level": currentLevel, "rotateUsed": rotateUsed]
           UserDefaults.standard.set(gameState, forKey: "savedGameState")
           print("Oyun durumu kaydedildi.")
       }


       func loadGameState() {
           guard let gameState = UserDefaults.standard.dictionary(forKey: "savedGameState") else { return }
           
           print("Kaydedilmiş oyun durumu yükleniyor...")
           
           score = gameState["score"] as? Int ?? 0
           currentLevel = gameState["level"] as? Int ?? 1
           rotateUsed = gameState["rotateUsed"] as? Bool ?? false
           
           if let savedGrid = gameState["gridState"] as? [[String: Any]] {
               for cellData in savedGrid {
                   let r = cellData["row"] as! Int
                   let c = cellData["col"] as! Int
                   let colorArray = cellData["color"] as! [CGFloat]
                   let color = SKColor(red: colorArray[0], green: colorArray[1], blue: colorArray[2], alpha: colorArray[3])
                   let typeString = cellData["type"] as? String ?? "normal"
                   
                   let square = SKShapeNode(rectOf: CGSize(width: cellSize - 2, height: cellSize - 2), cornerRadius: 3)
                   square.fillColor = color
                   addBevelEffect(to: square, baseColor: color, fullCellSize: cellSize)
                   
                   // Düzeltilmiş Yükleme: Emojileri geri yükle.
                   if typeString == "bomb" {
                       let bombLabel = SKLabelNode(text: "💣"); bombLabel.fontSize = (cellSize - 2) * 0.55; bombLabel.fontName = "AppleColorEmoji"; bombLabel.verticalAlignmentMode = .center; bombLabel.horizontalAlignmentMode = .center; bombLabel.zPosition = 5; square.addChild(bombLabel)
                   } else if typeString == "rainbow" {
                       let rainbowLabel = SKLabelNode(text: "🌈"); rainbowLabel.fontSize = (cellSize - 2) * 0.55; rainbowLabel.fontName = "AppleColorEmoji"; rainbowLabel.verticalAlignmentMode = .center; rainbowLabel.horizontalAlignmentMode = .center; rainbowLabel.zPosition = 5; square.addChild(rainbowLabel)
                   }
                   
                   square.position = gridPositionToPoint(row: r, col: c)
                   self.addChild(square)
                   
                   gridState[r][c] = 1
                   gridSpriteMap[r][c] = square
               }
           }

           if let savedNextBlocks = gameState["nextBlocks"] as? [[String: Any]] {
               nextBlocks.forEach { $0.removeFromParent() }
               nextBlocks.removeAll()
               let y: CGFloat = 100
               let dx: CGFloat = 90
               let positions = [CGPoint(x: size.width/2 - dx, y: y), CGPoint(x: size.width/2 + dx, y: y)]
               for (index, blockData) in savedNextBlocks.enumerated() {
                   let cellsArray = blockData["cells"] as! [[Int]]
                   let cells = cellsArray.map { ($0[0], $0[1]) }
                   let colorArray = blockData["color"] as! [CGFloat]
                   let color = SKColor(red: colorArray[0], green: colorArray[1], blue: colorArray[2], alpha: colorArray[3])
                   let typeString = blockData["type"] as! String
                   let type: BlockType = typeString == "bomb" ? .bomb : (typeString == "rainbow" ? .rainbow : .normal)
                   let shape = BlockShape(cells: cells, color: color, type: type)
                   let block = spawnBlock(from: shape, at: positions[index])
                   block.setScale(0.8)
                   if index == 0 { addChild(block) }
                   nextBlocks.append(block)
               }
           }

           updateScoreLabel()
           if levelLabel != nil { levelLabel.text = "Level: \(currentLevel)" }
           updateRotateButtonState()
           layoutPreview()
           updateBottomBlockStyles()
       }

       func clearSavedGame() {
           UserDefaults.standard.removeObject(forKey: "savedGameState")
           print("Kaydedilmiş oyun silindi.")
       }
       
   }
extension SKColor {
    func lighter(by percentage: CGFloat = 0.2) -> SKColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        self.getRed(&r, green: &g, blue: &b, alpha: &a)
        return SKColor(red: min(r + percentage, 1.0),
                       green: min(g + percentage, 1.0),
                       blue: min(b + percentage, 1.0),
                       alpha: a)
    }

    func darker(by percentage: CGFloat = 0.2) -> SKColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        self.getRed(&r, green: &g, blue: &b, alpha: &a)
        return SKColor(red: max(r - percentage, 0.0),
                       green: max(g - percentage, 0.0),
                       blue: max(b - percentage, 0.0),
                       alpha: a)
    }
    
    func isApproximatelyEqualTo(_ color: SKColor, tolerance: CGFloat = 0.01) -> Bool {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        self.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        color.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        // Alpha'yı genellikle bu tür karşılaştırmalarda ihmal ederiz,
        // ama isterseniz ekleyebilirsiniz: abs(a1 - a2) < tolerance
        return abs(r1 - r2) < tolerance &&
               abs(g1 - g2) < tolerance &&
               abs(b1 - b2) < tolerance
    }
    
    
}
