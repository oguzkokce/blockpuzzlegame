
// GameScene.swift
import SpriteKit
import UIKit
import AVFoundation

let gridSize = 10
let cellSize: CGFloat = 40
var gridOrigin: CGPoint = .zero

struct BlockShape {
    let cells: [(Int, Int)]
    let color: SKColor
}

class GameScene: SKScene {
    private var nextBlocks: [SKNode] = []
    private var selectedNode: SKNode?
    private var lastValidPosition: CGPoint?
    private var isDragging = false
    private var gridNodes: [[SKShapeNode]] = []
    private var gridState: [[Int]] = []
    private var gridSpriteMap: [[SKSpriteNode?]] = []
    private var blockOffset: CGPoint = .zero
    private var scoreLabel: SKLabelNode!
    private var score = 0
    private var rotateUsed = false
    private var rotateButton: SKSpriteNode!
    private var comboCount = 0
    var audioPlayer: AVAudioPlayer?



    override func didMove(to view: SKView) {
        setupGame()
    }

    func setupGame() {
        rotateButton = SKSpriteNode(color: .orange, size: CGSize(width: 120, height: 50))
        rotateButton.position = CGPoint(x: size.width - 80, y: size.height - 60)
        rotateButton.name = "rotateButton"
        
        let label = SKLabelNode(text: "↻ Döndür")
        label.fontName = "AvenirNext-Bold"
        label.fontSize = 14
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.position = .zero
        rotateButton.addChild(label)
        
        scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        scoreLabel.fontSize = 24
        scoreLabel.fontColor = .white
        scoreLabel.position = CGPoint(x: size.width / 2, y: size.height - 140)
        scoreLabel.text = "Skor: 0"
        addChild(scoreLabel)

        // 🏆 High Score etiketi
        let highScoreLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        highScoreLabel.name = "highScoreLabel"
        highScoreLabel.fontSize = 18
        highScoreLabel.fontColor = .systemYellow
        highScoreLabel.position = CGPoint(x: size.width / 2, y: size.height - 170)
        highScoreLabel.text = "En Yüksek Skor: \(UserDefaults.standard.integer(forKey: "HighScore"))"
        addChild(highScoreLabel)
        
        
        let lockIcon = SKLabelNode(text: "🔒")
        lockIcon.name = "lockIcon"
        lockIcon.fontSize = 18
        lockIcon.fontColor = .white
        lockIcon.verticalAlignmentMode = .center
        lockIcon.position = CGPoint(x: 0, y: 0)
        lockIcon.alpha = 0  // Başta görünmez
        rotateButton.addChild(lockIcon)
        
        addChild(rotateButton)
        
        gridState = Array(repeating: Array(repeating: 0, count: gridSize), count: gridSize)
        gridNodes = Array(repeating: Array(repeating: SKShapeNode(), count: gridSize), count: gridSize)
        gridSpriteMap = Array(repeating: Array(repeating: nil, count: gridSize), count: gridSize)

        gridOrigin = CGPoint(
            x: (size.width - CGFloat(gridSize) * cellSize) / 2,
            y: (size.height - CGFloat(gridSize) * cellSize) / 2
        )

        backgroundColor = SKColor(red: 0.1, green: 0.12, blue: 0.2, alpha: 1.0)
        drawGrid()
        spawnNextBlocks()

      
        
        updateRotateButtonState()
    }

    func drawGrid() {
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let cell = SKShapeNode(rectOf: CGSize(width: cellSize - 1, height: cellSize - 1))
                cell.strokeColor = SKColor.gray.withAlphaComponent(0.3)
                cell.fillColor = SKColor.clear
                cell.lineWidth = 1
                cell.position = gridPositionToPoint(row: row, col: col)
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
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let touchedNode = atPoint(location)

        // ✅ Restart butonuna tıklandıysa oyunu yeniden başlat
        if touchedNode.name == "restartButton" {
            restartGame()
            return
        }

        // 🔄 Döndürme butonu kontrolü
        let isRotateButtonTapped = touchedNode.name == "rotateButton" || touchedNode.parent?.name == "rotateButton"

        if isRotateButtonTapped,
           !rotateUsed,
           let firstBlock = nextBlocks.first {

            rotateBlock(firstBlock)
            rotateUsed = true
            updateRotateButtonState()

            selectedNode = firstBlock
            lastValidPosition = firstBlock.position
            blockOffset = .zero
            isDragging = false

            return
        }

        // 🟢 Blok sürükleme
        if let parentNode = touchedNode.name == "draggable" ? touchedNode : touchedNode.parent,
           parentNode.name == "draggable",
           let firstBlock = nextBlocks.first,
           parentNode == firstBlock {

            selectedNode = parentNode
            selectedNode?.zPosition = 10
            lastValidPosition = parentNode.position
            isDragging = true
            blockOffset = CGPoint(x: parentNode.position.x - location.x, y: parentNode.position.y - location.y)

            if let positions = getBlockGridPositions(parentNode) {
                for pos in positions {
                    if pos.row >= 0 && pos.row < gridSize && pos.col >= 0 && pos.col < gridSize {
                        setGridValue(0, at: pos)
                    }
                }
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let node = selectedNode, isDragging else { return }
        let location = touch.location(in: self)
        let newPosition = CGPoint(x: location.x + blockOffset.x, y: location.y + blockOffset.y)
        node.position = newPosition

        if let positions = getBlockGridPositions(node) {
            let isValid = isValidPlacement(positions)
            node.alpha = isValid ? 1.0 : 0.5
            highlightGrid(positions: positions, isValid: isValid)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let node = selectedNode, isDragging else { return }
        isDragging = false

        if let positions = getBlockGridPositions(node), isValidPlacement(positions) {
            guard positions.count == node.children.count else {
                returnToLastValidPosition(node)
                return
            }
            for (index, pos) in positions.enumerated() {
                if let sprite = node.children[index] as? SKSpriteNode {
                    setGridValue(1, at: pos, sprite: sprite)
                }
            }
            snapAndPlaceBlock(node, at: positions)
            if let index = nextBlocks.firstIndex(of: node) {
                nextBlocks.remove(at: index)
                if nextBlocks.isEmpty {
                    spawnNextBlocks()
                }
            }
            checkGameOver()

        } else {
            returnToLastValidPosition(node)
        }
        resetGridHighlight()
        selectedNode = nil
    }

    func getBlockGridPositions(_ node: SKNode) -> [(row: Int, col: Int)]? {
        var positions: [(row: Int, col: Int)] = []

        for square in node.children {
            guard let part = square as? SKSpriteNode else { continue }

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

    func snapAndPlaceBlock(_ node: SKNode, at positions: [(row: Int, col: Int)]) {
        guard let firstSquare = node.children.first as? SKSpriteNode else { return }
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
        node.zPosition = 0
        node.alpha = 1.0
        lastValidPosition = finalPosition
        checkAndClearLines()


        
        
    }


    private func setGridValue(_ value: Int, at position: (row: Int, col: Int), sprite: SKSpriteNode? = nil) {
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
                    ? SKColor.green.withAlphaComponent(0.3)
                    : SKColor.red.withAlphaComponent(0.3)
            }
        }
    }

    func resetGridHighlight() {
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                gridNodes[row][col].fillColor = .clear
            }
        }
    }

    func returnToLastValidPosition(_ node: SKNode) {
        if let lastPos = lastValidPosition {
            node.run(SKAction.sequence([
                SKAction.move(to: lastPos, duration: 0.2),
                SKAction.run { [weak self] in
                    guard let self = self else { return }
                    node.alpha = 1.0
                    if let positions = self.getBlockGridPositions(node) {
                        for pos in positions {
                            self.setGridValue(1, at: pos)
                        }
                    }
                }
            ]))
        }
    }

    func rotateBlock(_ node: SKNode) {
        print("🚀 rotateBlock çağrıldı")

        guard node.children.count > 0 else { return }

        let originalPositions = node.children.compactMap { ($0 as? SKSpriteNode)?.position }

        print("📍 Orijinal pozisyonlar:")
        originalPositions.forEach { print($0) }

        let centerX = originalPositions.map { $0.x }.reduce(0, +) / CGFloat(originalPositions.count)
        let centerY = originalPositions.map { $0.y }.reduce(0, +) / CGFloat(originalPositions.count)
        let center = CGPoint(x: centerX, y: centerY)

        for (index, square) in node.children.enumerated() {
            if let sprite = square as? SKSpriteNode {
                let pos = originalPositions[index]
                let translated = CGPoint(x: pos.x - center.x, y: pos.y - center.y)
                let rotated = CGPoint(x: -translated.y, y: translated.x)
                let final = CGPoint(x: rotated.x + center.x, y: rotated.y + center.y)
                sprite.position = final
            }
        }
        
        print("🌀 Yeni pozisyonlar:")
        node.children.compactMap { ($0 as? SKSpriteNode)?.position }.forEach { print($0) }
        node.run(SKAction.rotate(byAngle: .pi / 2, duration: 0.1))

    


        // Yeni pozisyonlar geçerli mi kontrol et
        if let newPositions = getBlockGridPositions(node), isValidPlacement(newPositions) {
            highlightGrid(positions: newPositions, isValid: true)
            snapAndPlaceBlock(node, at: newPositions)
        } else {
            // Geri al
            for (index, square) in node.children.enumerated() {
                if let sprite = square as? SKSpriteNode {
                    sprite.position = originalPositions[index]
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self else { return }

                if let block = self.nextBlocks.first,
                   !self.canPlaceBlock(block, considerRotation: false) {

                    if !self.canPlaceBlock(block, considerRotation: true) {
                        print("🟥 Döndürme sonrası da yerleşemiyor. GAME OVER.")
                        self.showGameOver()
                    } else {
                        print("✅ Döndürme sonrası şekil yerleşebilir hale geldi.")
                    }
                } else {
                    print("✅ Döndürme sonrası mevcut haliyle yerleşebilir.")
                }
            }
    }



    func spawnNextBlocks() {
        for block in nextBlocks {
            block.removeFromParent()
        }
        nextBlocks.removeAll()

        let spawnPositions: [CGPoint] = [
            CGPoint(x: 100, y: 80),
            CGPoint(x: 200, y: 80),
            CGPoint(x: 300, y: 80)
        ]

        for i in 0..<3 {
            let shape = generateRandomShape()
            let block = spawnBlock(from: shape, at: spawnPositions[i])
            addChild(block)
            nextBlocks.append(block)
        }

        rotateUsed = false
        selectedNode = nil
        updateRotateButtonState()
        checkGameOver()
    }

    func generateRandomShape() -> BlockShape {
        let shapes: [[(Int, Int)]] = [
            [(0,0), (1,0), (1,1)],
            [(0,0), (0,1), (0,2)],
            [(0,0), (1,0), (0,1), (1,1)],
            [(0,0), (1,0), (2,0), (3,0)],
            [(0,0), (0,1), (0,2), (1,2)],
            [(0,0), (1,0), (1,1), (2,1)],
            [(0,0), (1,0), (2,0), (2,1)],       // L
            [(0,0), (1,0), (1,-1), (1,1)],      // T
            [(0,0), (0,1), (1,1), (1,2)],       // Z
            [(0,0), (1,0), (2,0), (2,-1)]       // ters L
        ]

        let colors: [SKColor] = [
            .cyan, .orange, .green, .yellow,
            .systemPink, .magenta, .blue, .systemRed, .purple
        ]

        let randomIndex = Int.random(in: 0..<shapes.count)
        let randomColor = colors.randomElement() ?? .white
        return BlockShape(cells: shapes[randomIndex], color: randomColor)
    }


    func spawnBlock(from shape: BlockShape, at position: CGPoint) -> SKNode {
        let blockNode = SKNode()
        blockNode.name = "draggable"

        for cell in shape.cells {
            let square = SKSpriteNode(color: shape.color, size: CGSize(width: cellSize - 2, height: cellSize - 2))
            square.position = CGPoint(
                x: CGFloat(cell.0) * cellSize,
                y: CGFloat(cell.1) * cellSize
            )
            blockNode.addChild(square)
        }

        // 🔁 Blok merkezi etrafında dönebilsin diye anchor ortalanmalı
        let centerX = blockNode.calculateAccumulatedFrame().midX
        let centerY = blockNode.calculateAccumulatedFrame().midY
        for square in blockNode.children {
            square.position.x -= centerX
            square.position.y -= centerY
        }

        blockNode.position = position
        return blockNode
    }


    func checkAndClearLines() {
        var fullRows: [Int] = []
        var fullCols: [Int] = []

        for row in 0..<gridSize {
            if gridState[row].allSatisfy({ $0 == 1 }) {
                fullRows.append(row)
            }
        }

        for col in 0..<gridSize {
            if (0..<gridSize).allSatisfy({ row in gridState[row][col] == 1 }) {
                fullCols.append(col)
            }
        }

        let cellsToClear = fullRows.flatMap { row in (0..<gridSize).map { (row, $0) } } +
                           fullCols.flatMap { col in (0..<gridSize).map { ($0, col) } }

        let lineCount = fullRows.count + fullCols.count
        if lineCount > 0 {
            comboCount += 1

            if comboCount >= 2 {
                showComboEffect(level: comboCount)
            }
        } else {
            comboCount = 0
        }


        let basePoints = lineCount * 120
        let bonus = (lineCount >= 3) ? 20 : 0

        score += basePoints + bonus
        scoreLabel.text = "Skor: \(score)"

        for (row, col) in cellsToClear {
            gridState[row][col] = 0
            if let sprite = gridSpriteMap[row][col] {
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
        // 🎯 High Score kontrolü
        let currentHigh = UserDefaults.standard.integer(forKey: "HighScore")
        if score > currentHigh {
            UserDefaults.standard.set(score, forKey: "HighScore")
            if let highScoreLabel = childNode(withName: "highScoreLabel") as? SKLabelNode {
                highScoreLabel.text = "En Yüksek Skor: \(score)"
            }
        }
        
    }
    func showComboEffect() {
        let comboLabel = SKLabelNode(text: "✨ KOMBO! ✨")
        comboLabel.fontName = "AvenirNext-Bold"
        comboLabel.fontSize = 36
        comboLabel.fontColor = .systemYellow
        comboLabel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        comboLabel.zPosition = 100
        comboLabel.alpha = 0
        addChild(comboLabel)

        let fadeIn = SKAction.fadeIn(withDuration: 0.2)
        let scaleUp = SKAction.scale(to: 1.4, duration: 0.2)
        let wait = SKAction.wait(forDuration: 0.6)
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        let remove = SKAction.removeFromParent()

        let groupIn = SKAction.group([fadeIn, scaleUp])
        let sequence = SKAction.sequence([groupIn, wait, fadeOut, remove])
        comboLabel.run(sequence)
    }
    
    func checkGameOver() {
        print("🧠 checkGameOver başladı...")

        guard let block = nextBlocks.first else {
            print("❗ Blok yok.")
            return
        }

        // Blok yerleştirilebiliyor mu?
        if canPlaceBlock(block, considerRotation: false) {
            print("✅ Blok yerleşebilir. Oyun devam.")
            return
        }

        // Yerleşemiyorsa ve döndürme hakkı varsa — bekle
        if !rotateUsed {
            print("🔁 Yerleşemiyor ama döndürme hakkı var. Oyuncuya bırakıyoruz.")
            return
        }

        // Döndürme hakkı da yoksa
        print("🟥 Blok yerleşemez ve döndürme hakkı da yok. GAME OVER.")
        showGameOver()
    }

    func canPlaceBlock(_ block: SKNode, considerRotation: Bool) -> Bool {
        let originalPositions = block.children.compactMap { ($0 as? SKSpriteNode)?.position }
        guard originalPositions.count == block.children.count else { return false }

        // normalize shape
        let minX = originalPositions.map { $0.x }.min() ?? 0
        let minY = originalPositions.map { $0.y }.min() ?? 0
        let shapeOffsets = originalPositions.map {
            (Int(round(($0.x - minX) / cellSize)), Int(round(($0.y - minY) / cellSize)))
        }

        // 1. Normal şekil ile deneyelim
        if canPlaceShapeAnywhere(shapeOffsets) {
            return true
        }

        // 2. Döndürülmüş şekli de kontrol edelim (isteğe bağlı)
        if considerRotation {
            let rotatedOffsets = shapeOffsets.map { (x, y) in (-y, x) }
            if canPlaceShapeAnywhere(rotatedOffsets) {
                return true
            }
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





    func showGameOver() {
        let overlay = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height))
        overlay.position = CGPoint(x: size.width / 2, y: size.height / 2)
        overlay.fillColor = .black
        overlay.alpha = 0.7
        overlay.zPosition = 1000
        overlay.name = "gameOverOverlay" // ✅ bunu ekle!
        addChild(overlay)

        let gameOverLabel = SKLabelNode(text: "🟥 GAME OVER 🟥")
        gameOverLabel.fontName = "AvenirNext-Bold"
        gameOverLabel.fontSize = 42
        gameOverLabel.fontColor = .red
        gameOverLabel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        gameOverLabel.zPosition = 1001
        addChild(gameOverLabel)
        
        let restartButton = SKLabelNode(text: "🔄 Yeniden Başla")
          restartButton.name = "restartButton"
          restartButton.fontName = "AvenirNext-Bold"
          restartButton.fontSize = 28
          restartButton.fontColor = .white
          restartButton.position = CGPoint(x: size.width / 2, y: size.height / 2 - 20)
          restartButton.zPosition = 1001
          addChild(restartButton)
    }
    
    func restartGame() {
        print("🔄 Oyun yeniden başlatılıyor...")

        // Game over overlay ve yazılar silinsin
        childNode(withName: "gameOverOverlay")?.removeFromParent()
        childNode(withName: "restartButton")?.removeFromParent()
        children.first(where: { ($0 as? SKLabelNode)?.text?.contains("GAME OVER") == true })?.removeFromParent()

        // Grid temizle
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                gridState[row][col] = 0
                gridSpriteMap[row][col]?.removeFromParent()
                gridSpriteMap[row][col] = nil
            }
        }

        // Skoru sıfırla
        score = 0
        scoreLabel.text = "Skor: 0"

        // Blokları kaldır
        for block in nextBlocks {
            block.removeFromParent()
        }
        nextBlocks.removeAll()

        // 🔁 Durumları resetle
        rotateUsed = false
        selectedNode = nil
        isDragging = false
        lastValidPosition = nil

        // 🔄 Buton güncelle
        updateRotateButtonState()

        // 🔥 Yeni bloklar getir
        spawnNextBlocks()
    }
    
    func showComboEffect(level: Int) {
        let labelText = "✨ \(level)x KOMBO! ✨"
        let comboLabel = SKLabelNode(text: labelText)
        comboLabel.fontName = "AvenirNext-Bold"
        comboLabel.fontSize = 36 + CGFloat(level * 2)
        comboLabel.fontColor = .systemYellow
        comboLabel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        comboLabel.zPosition = 100
        comboLabel.alpha = 0
        addChild(comboLabel)

        let fadeIn = SKAction.fadeIn(withDuration: 0.2)
        let scaleUp = SKAction.scale(to: 1.4, duration: 0.2)
        let wait = SKAction.wait(forDuration: 0.6)
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        let remove = SKAction.removeFromParent()

        let groupIn = SKAction.group([fadeIn, scaleUp])
        let sequence = SKAction.sequence([groupIn, wait, fadeOut, remove])
        comboLabel.run(sequence)
    }
    
    




}
