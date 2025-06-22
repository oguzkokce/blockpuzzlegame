import SpriteKit

class ArcadeLabelNode: SKNode {
    
    private var mainLabel: SKLabelNode
    private var shadowLabel: SKLabelNode
    
    var text: String? {
        didSet {
            mainLabel.text = text
            shadowLabel.text = text
        }
    }
    
    var fontColor: SKColor {
        didSet {
            mainLabel.fontColor = fontColor
        }
    }
    
    init(fontNamed fontName: String, text: String, fontSize: CGFloat, fontColor: SKColor = .white) {
        
        // 1. Gölge Etiketi (En altta)
        shadowLabel = SKLabelNode(fontNamed: fontName)
        shadowLabel.text = text
        shadowLabel.fontSize = fontSize
        shadowLabel.fontColor = .black.withAlphaComponent(0.7)
        shadowLabel.position = CGPoint(x: 2, y: -2) // Sağa ve aşağıya kaydır
        shadowLabel.zPosition = 1
        
        // 2. Ana Etiket (En üstte)
        mainLabel = SKLabelNode(fontNamed: fontName)
        mainLabel.text = text
        mainLabel.fontSize = fontSize
        mainLabel.fontColor = fontColor
        mainLabel.zPosition = 2 // Gölgenin önünde
        
        self.fontColor = fontColor
        
        super.init()
        
        // Etiketleri ana node'a ekle
        addChild(shadowLabel)
        addChild(mainLabel)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
