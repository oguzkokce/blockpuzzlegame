import SpriteKit

class MenuScene: SKScene {
    override func didMove(to view: SKView) {
        // --- ARKA PLAN (Retro Neon Metro Style) ---
        self.backgroundColor = SKColor(red: 0.08, green: 0.09, blue: 0.16, alpha: 1.0)
        
        // Neon Glow Diskler
        let neonColors: [SKColor] = [
            SKColor(red: 1, green: 0.36, blue: 0.72, alpha: 1), // pembe
            SKColor(red: 0.27, green: 0.86, blue: 0.96, alpha: 1), // teal
            SKColor(red: 0.4, green: 0.35, blue: 0.88, alpha: 1), // indigo
            SKColor(red: 1.0, green: 0.8, blue: 0.16, alpha: 1) // sarı
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
        
        // CRT Scanline (Yatay Çizgiler)
        for i in stride(from: 0, to: Int(size.height), by: 8) {
            let line = SKShapeNode(rectOf: CGSize(width: size.width, height: 1))
            line.position = CGPoint(x: size.width/2, y: CGFloat(i))
            line.fillColor = SKColor.white.withAlphaComponent(0.06)
            line.strokeColor = .clear
            line.zPosition = -18
            addChild(line)
        }
        
        // Neon geometrik desenler
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
        
        // Pixel yıldızlar
        let starColors: [SKColor] = [
            .white,
            SKColor(red: 1, green: 0.96, blue: 0.6, alpha: 1),
            SKColor(red: 1, green: 0.6, blue: 0.8, alpha: 1),
            SKColor(red: 0.7, green: 1, blue: 1, alpha: 1),
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
        
        // --- AYARLAR BUTONU ---
        let settingsButton = SKShapeNode(circleOfRadius: 24)
        settingsButton.name = "settingsButton"
        settingsButton.position = CGPoint(x: size.width - 48, y: size.height - 48)
        settingsButton.fillColor = SKColor.black.withAlphaComponent(0.72)
        settingsButton.strokeColor = SKColor.cyan
        settingsButton.lineWidth = 3
        settingsButton.zPosition = 20
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
        
        // Ortasına ikon (dişli yerine pixel tarzı kutular veya retro dişli)
        let centerIcon = SKLabelNode(text: "☰") // Retro ayar çizgisi
        centerIcon.fontName = "AvenirNext-Bold"
        centerIcon.fontSize = 22
        centerIcon.fontColor = SKColor.cyan
        centerIcon.verticalAlignmentMode = .center
        centerIcon.horizontalAlignmentMode = .center
        centerIcon.zPosition = 2
        settingsButton.addChild(centerIcon)
        
        // --- BAŞLIK ---
        // --- RETRO "PATLAT!" BAŞLIĞI ve Mini LOGO ---
        // Metin
        let titleText = "PATLAT!"
        
        // 1. Neon Glow: Arkada büyük cyan-mavi parıltı
        let titleGlow = SKLabelNode(text: titleText)
        titleGlow.fontName = "AvenirNext-Bold"
        titleGlow.fontSize = 68
        titleGlow.fontColor = SKColor.cyan.withAlphaComponent(0.38)
        titleGlow.position = CGPoint(x: size.width/2, y: size.height * 0.76)
        titleGlow.zPosition = 12
        titleGlow.alpha = 0.92
        addChild(titleGlow)
        
        let glowPulseUp = SKAction.scale(to: 1.08, duration: 0.9)
        let glowPulseDown = SKAction.scale(to: 1.0, duration: 0.7)
        titleGlow.run(SKAction.repeatForever(SKAction.sequence([glowPulseUp, glowPulseDown])))
        
        // 2. Shadow: Retro siyah gölge
        let titleShadow = SKLabelNode(text: titleText)
        titleShadow.fontName = "AvenirNext-Bold"
        titleShadow.fontSize = 62
        titleShadow.fontColor = SKColor.black.withAlphaComponent(0.8)
        titleShadow.position = CGPoint(x: size.width/2 + 6, y: size.height * 0.76 - 7)
        titleShadow.zPosition = 13
        titleShadow.alpha = 0.96
        addChild(titleShadow)
        
        // 3. İki renkli asıl başlık (retro stil)
        // İstersen burada “gradient” etkisi için iki ayrı label üst üste koyabilirsin
        let titleLabelTop = SKLabelNode(text: titleText)
        titleLabelTop.fontName = "AvenirNext-Bold"
        titleLabelTop.fontSize = 62
        titleLabelTop.fontColor = SKColor.yellow
        titleLabelTop.position = CGPoint(x: size.width/2, y: size.height * 0.76 + 3)
        titleLabelTop.zPosition = 15
        titleLabelTop.alpha = 1.0
        addChild(titleLabelTop)
        
        let titleLabelBottom = SKLabelNode(text: titleText)
        titleLabelBottom.fontName = "AvenirNext-Bold"
        titleLabelBottom.fontSize = 62
        titleLabelBottom.fontColor = SKColor.systemPink.withAlphaComponent(0.94)
        titleLabelBottom.position = CGPoint(x: size.width/2, y: size.height * 0.76 - 4)
        titleLabelBottom.zPosition = 14
        titleLabelBottom.alpha = 0.83
        addChild(titleLabelBottom)
        
        // 4. Altta ince gradient bar (light efekti)
        let gradientBar = SKShapeNode(rectOf: CGSize(width: 300, height: 14), cornerRadius: 8)
        gradientBar.position = CGPoint(x: size.width/2, y: size.height * 0.76 - 39)
        gradientBar.fillColor = SKColor.white.withAlphaComponent(0.13)
        gradientBar.strokeColor = SKColor.cyan.withAlphaComponent(0.19)
        gradientBar.zPosition = 11
        addChild(gradientBar)
        
        // 5. Mini Retro LOGO: 2 tane yan yana tetris bloku gibi kutu ve küçük yıldız
        
        
        // Küçük yıldız efekti
        
        
        // --- START BUTONU (Neon çerçeveli büyük buton, sprite değil, dinamik) ---
        let buttonWidth: CGFloat = 280
        let buttonHeight: CGFloat = 80
        let buttonRect = SKShapeNode(rectOf: CGSize(width: buttonWidth, height: buttonHeight), cornerRadius: 18)
        buttonRect.name = "startButton"
        buttonRect.fillColor = SKColor.black.withAlphaComponent(0.65)
        buttonRect.strokeColor = SKColor.systemPink.withAlphaComponent(0.85)
        buttonRect.lineWidth = 5
        buttonRect.position = CGPoint(x: size.width/2, y: size.height * 0.4)
        buttonRect.zPosition = 11
        addChild(buttonRect)
        // Animasyonlu Neon Parlama (hafif pulse)
        let pulseUp = SKAction.scale(to: 1.05, duration: 0.8)
        let pulseDown = SKAction.scale(to: 1.0, duration: 0.8)
        let pulseSeq = SKAction.sequence([pulseUp, pulseDown])
        buttonRect.run(SKAction.repeatForever(pulseSeq))
        
        // Buton üstü yazı
        let startButtonLabel = SKLabelNode(text: "OYUNA BAŞLA")
        startButtonLabel.fontName = "AvenirNext-Bold"
        startButtonLabel.fontSize = 28
        startButtonLabel.fontColor = .white
        startButtonLabel.verticalAlignmentMode = .center
        startButtonLabel.horizontalAlignmentMode = .center
        startButtonLabel.position = .zero
        startButtonLabel.zPosition = 13
        buttonRect.addChild(startButtonLabel)
    }
    
    // Dokunmalar
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let node = atPoint(location)
        
        if node.name == "startButton" {
            let scaleDown = SKAction.scale(to: 0.9, duration: 0.09)
            let scaleUp = SKAction.scale(to: 1.0, duration: 0.09)
            node.run(SKAction.sequence([scaleDown, scaleUp])) {
                let gameScene = GameScene(size: self.size)
                gameScene.scaleMode = .aspectFill
                self.view?.presentScene(gameScene, transition: .fade(withDuration: 0.5))
            }
        }
        if node.name == "settingsButton" {
            showSettingsMenu()
            // Titreşim açılırsa haptic feedback ver:
            if Settings.isHapticEnabled {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
            return
        }
        if let panel = childNode(withName: "settingsPanel") {
            let touchLocation = touch.location(in: panel)
            for subNode in panel.nodes(at: touchLocation) {
                if subNode.name == "soundSwitch" {
                    Settings.isSoundEnabled.toggle()
                    (subNode as? SKLabelNode)?.text = Settings.isSoundEnabled ? "AÇIK" : "KAPALI"
                    (subNode as? SKLabelNode)?.fontColor = Settings.isSoundEnabled ? .systemGreen : .systemRed
                    // Haptic ve Ses anında geri bildirim:
                    if Settings.isHapticEnabled {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }
                    if Settings.isSoundEnabled {
                        let soundAction = SKAction.playSoundFileNamed("button_tap.wav", waitForCompletion: false)
                        self.run(soundAction)
                    }
                    return
                }
                if subNode.name == "hapticSwitch" {
                    Settings.isHapticEnabled.toggle()
                    (subNode as? SKLabelNode)?.text = Settings.isHapticEnabled ? "AÇIK" : "KAPALI"
                    (subNode as? SKLabelNode)?.fontColor = Settings.isHapticEnabled ? .systemGreen : .systemRed
                    if Settings.isHapticEnabled {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                    }
                    let soundAction = SKAction.playSoundFileNamed("button_tap.wav", waitForCompletion: false)
                    self.run(soundAction)
                    return
                }
                if subNode.name == "closeSettings" {
                    childNode(withName: "settingsPanel")?.removeFromParent()
                    childNode(withName: "settingsOverlay")?.removeFromParent()
                    if Settings.isSoundEnabled {
                        let soundAction = SKAction.playSoundFileNamed("button_tap.wav", waitForCompletion: false)
                        self.run(soundAction)
                    }
                    return
                }
            }
        }
    }
    
    // --- AYARLAR MENÜSÜ ---
    func showSettingsMenu() {
        // Arka yarı saydam overlay
        let overlay = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height))
        overlay.position = CGPoint(x: size.width/2, y: size.height/2)
        overlay.fillColor = SKColor.black.withAlphaComponent(0.57)
        overlay.zPosition = 100
        overlay.name = "settingsOverlay"
        addChild(overlay)
        
        // Panel
        let panel = SKShapeNode(rectOf: CGSize(width: 320, height: 170), cornerRadius: 22)
        panel.position = CGPoint(x: size.width/2, y: size.height/2)
        panel.fillColor = SKColor(red: 0.13, green: 0.14, blue: 0.2, alpha: 1.0)
        panel.strokeColor = SKColor.cyan
        panel.lineWidth = 3
        panel.zPosition = 110
        panel.name = "settingsPanel"
        addChild(panel)
        
        // Retro panel üst başlık
        let title = SKLabelNode(text: "Ayarlar")
        title.fontName = "AvenirNext-Bold"
        title.fontSize = 28
        title.fontColor = .cyan
        title.position = CGPoint(x: 0, y: 55)
        title.zPosition = 111
        panel.addChild(title)
        
        // Ses Ayarı
        let soundLabel = SKLabelNode(text: "Ses Efekti")
        soundLabel.fontName = "AvenirNext-Bold"
        soundLabel.fontSize = 19
        soundLabel.fontColor = .white
        soundLabel.horizontalAlignmentMode = .left
        soundLabel.position = CGPoint(x: -100, y: 20)
        soundLabel.zPosition = 111
        panel.addChild(soundLabel)
        let soundSwitch = SKLabelNode(text: Settings.isSoundEnabled ? "AÇIK" : "KAPALI")
        soundSwitch.name = "soundSwitch"
        soundSwitch.fontName = "AvenirNext-Bold"
        soundSwitch.fontSize = 19
        soundSwitch.fontColor = Settings.isSoundEnabled ? .systemGreen : .systemRed
        soundSwitch.position = CGPoint(x: 90, y: 20)
        soundSwitch.zPosition = 111
        panel.addChild(soundSwitch)
        
        // Titreşim Ayarı
        let hapticLabel = SKLabelNode(text: "Titreşim")
        hapticLabel.fontName = "AvenirNext-Bold"
        hapticLabel.fontSize = 19
        hapticLabel.fontColor = .white
        hapticLabel.horizontalAlignmentMode = .left
        hapticLabel.position = CGPoint(x: -100, y: -24)
        hapticLabel.zPosition = 111
        panel.addChild(hapticLabel)
        let hapticSwitch = SKLabelNode(text: Settings.isHapticEnabled ? "AÇIK" : "KAPALI")
        hapticSwitch.name = "hapticSwitch"
        hapticSwitch.fontName = "AvenirNext-Bold"
        hapticSwitch.fontSize = 19
        hapticSwitch.fontColor = Settings.isHapticEnabled ? .systemGreen : .systemRed
        hapticSwitch.position = CGPoint(x: 90, y: -24)
        hapticSwitch.zPosition = 111
        panel.addChild(hapticSwitch)
        
        // Kapat Butonu
        let closeButton = SKLabelNode(text: "Kapat")
        closeButton.name = "closeSettings"
        closeButton.fontName = "AvenirNext-Bold"
        closeButton.fontSize = 18
        closeButton.fontColor = .systemIndigo
        closeButton.position = CGPoint(x: 0, y: -66)
        closeButton.zPosition = 112
        panel.addChild(closeButton)
    }
    
}
