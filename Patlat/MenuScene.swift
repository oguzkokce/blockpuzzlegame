import SpriteKit

class MenuScene: SKScene {
    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.1, green: 0.12, blue: 0.2, alpha: 1.0)

        let titleLabel = SKLabelNode(text: "🎮 Patlat!")
        titleLabel.fontName = "AvenirNext-Bold"
        titleLabel.fontSize = 50
        titleLabel.position = CGPoint(x: size.width/2, y: size.height * 0.65)
        addChild(titleLabel)

        let startButton = SKLabelNode(text: "Oyuna Başla")
        startButton.name = "startButton"
        startButton.fontName = "AvenirNext-Bold"
        startButton.fontSize = 28
        startButton.fontColor = .white
        startButton.position = CGPoint(x: size.width/2, y: size.height * 0.4)
        addChild(startButton)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let node = atPoint(location)

        if node.name == "startButton" {
            let gameScene = GameScene(size: size)
            gameScene.scaleMode = .aspectFill
            view?.presentScene(gameScene, transition: .fade(withDuration: 0.5))
        }
    }
}
