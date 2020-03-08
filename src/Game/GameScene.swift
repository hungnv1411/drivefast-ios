//
//  GameScene.swift
//  Retro
//
//  Created by Atilla Özder on 10.10.2019.
//  Copyright © 2019 Atilla Özder. All rights reserved.
//

import SpriteKit
import GameplayKit
import CoreMotion

// MARK: - Global Variables

public var gameCount: Double = 0

// MARK: - SceneDelegate

protocol SceneDelegate: class {
    func scene(_ scene: GameScene, didFinishGameWithScore score: Int)
    func scene(_ scene: GameScene, shouldPresentRewardBasedVideoAd present: Bool)
    func scene(_ scene: GameScene, shouldPresentMenuScene present: Bool)
}

// MARK: - GameScene

class GameScene: SKScene {
    
    // MARK: - Variables
    
    struct Cars {
        let player = "player"
        let car = "car"
    }
    
    struct Actions {
        let addCar = "add_car"
    }
    
    private let motionManager = CMMotionManager()
    weak var sceneDelegate: SceneDelegate?
    
    lazy var playerNode: SKSpriteNode = {
        let node = SKSpriteNode(imageNamed: "car1")
        node.setScale(to: frame.width / 3)
        let posY = (node.size.height / 2) + 20 + insets.bottom
        node.position = CGPoint(x: frame.width / 2, y: posY)
        node.zPosition = 1
        node.name = Cars().player
        
        node.physicsBody = SKPhysicsBody(texture: node.texture!, size: node.size)
        node.physicsBody?.isDynamic = true
        node.physicsBody?.categoryBitMask = Category.player.rawValue
        node.physicsBody?.contactTestBitMask = Category.car.rawValue
        node.physicsBody?.collisionBitMask = 0
        return node
    }()
    
    lazy var roadNode: SKShapeNode = {
        let roadSize: CGSize = .init(width: frame.width, height: frame.height * 2)
        let node = SKShapeNode(rectOf: roadSize)
        node.fillColor = .roadColor
        node.strokeColor = .darkGray
        node.position = .init(x: frame.midX, y: frame.minY)
        node.zPosition = -1
        return node
    }()
    
    lazy var roadLineNode: SKShapeNode = {
        let node = SKShapeNode(rectOf: .init(width: 8, height: 50))
        node.zPosition = -1
        let color = UIColor(red: 250, green: 250, blue: 250)
        node.fillColor = color
        node.strokeColor = color
        return node
    }()
    
    lazy var scoreLabel: SKLabelNode = {
        let lbl = SKLabelNode(text: "Score: 0")
        lbl.position = CGPoint(x: 70, y: frame.size.height - 40 - insets.top)
        lbl.fontName = SKViewFactory.fontName
        lbl.fontSize = 28
        lbl.fontColor = UIColor.white
        lbl.zPosition = 2
        return lbl
    }()
    
    lazy var singleCoin: SKSpriteNode = {
        return SKViewFactory().buildCoin(rect: self.frame, type: .single)
    }()
    
    lazy var multipleCoins: SKSpriteNode = {
        return SKViewFactory().buildCoin(rect: self.frame, type: .multiple)
    }()
    
    lazy var coinBag: SKSpriteNode = {
        return SKViewFactory().buildCoin(rect: self.frame, type: .bag)
    }()
    
    var score: Int = 0 {
        didSet {
            scoreLabel.text = "Score: \(score)"
        }
    }
        
    let explosionNode: SKEmitterNode = {
        return SKEmitterNode(fileNamed: "Explosion")!
    }()
    
    let coinSound = SKAction.playSoundFileNamed("coin.wav", waitForCompletion: false)
    let explosionSound = SKAction.playSoundFileNamed("explosion.wav", waitForCompletion: false)

    /// safe area insets of the game view controller
    lazy var insets: UIEdgeInsets = .zero
    lazy var videoWasPresented: Bool = false
    lazy var gameOver: Bool = false

    private var remainingLives: [SKSpriteNode] = []
    private var cachedCars = [SKTexture: SKPhysicsBody]()
    
    // MARK: - Game Life Cycle
    
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        startGame()
        
        self.addChild(roadNode)
        
        self.physicsWorld.gravity = CGVector(dx: 0, dy: 0)
        self.physicsWorld.contactDelegate = self
        
        let roadLine: [SKAction] = [
            .wait(forDuration: 0.30),
            .run(addRoadLine, queue: .global(qos: .userInteractive))
        ]
        
        run(.repeatForever(.sequence(roadLine)))
        
        let addCar: [SKAction] = [
            .wait(forDuration: 1),
            .run(addRandomCar, queue: .global(qos: .userInteractive))
        ]
        
        run(.repeatForever(.sequence(addCar)), withKey: Actions().addCar)
    }
    
    func startGame() {
        gameCount += 1
        addChild(playerNode)
        
        score = 0
        addChild(scoreLabel)
        
        setupLives(count: 3)
        setupMotionManager()
        
        let actions: [SKAction] = [
            .wait(forDuration: 5),
            .run(addCoin, queue: .global(qos: .userInteractive))
        ]
        
        run(.repeatForever(.sequence(actions)))
    }
    
    func continueGame() {
        addChild(playerNode)
        
        self.setupLives(count: 1)
        self.gameOver = false
        self.isPaused = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.action(forKey: Actions().addCar)?.speed = 1
        }
    }
    
    func stopGame() {
        self.sceneDelegate?.scene(self, didFinishGameWithScore: score)
        
        if !videoWasPresented {
            self.isPaused = true
            self.action(forKey: Actions().addCar)?.speed = 0
            setupNewGameButton()
            setupPlayVideoButton()
        } else {
            self.sceneDelegate?.scene(self, shouldPresentMenuScene: true)
        }
    }
    
    // MARK: - Setup Variable Helpers
    
    private func setupLives(count: Int) {
        let size = CGSize(width: 40, height: 50)
        var posX = frame.maxX - (size.width / 2) - 6
        let posY = frame.maxY - insets.top - 30
        for _ in 0..<count {
            let texture = SKTexture(imageNamed: "car1")
            let node = SKSpriteNode(texture: texture)
            node.size = size
            node.position = CGPoint(x: posX, y: posY)
            node.zPosition = 2
            node.scaleAspectFill(to: size)
            
            let body = SKPhysicsBody(texture: texture, size: size)
            body.collisionBitMask = 0
            node.physicsBody = body
            
            remainingLives.append(node)
            addChild(node)
            posX -= ((size.width / 2) + 6)
        }
    }
    
    private func setupMotionManager() {
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] (data, error) in
            guard let strongSelf = self, let data = data else { return }
            
            var posX = strongSelf.playerNode.position.x + CGFloat(data.acceleration.x * 20)
            let roadMinX = strongSelf.frame.minX + 30
            let roadMaxX = strongSelf.frame.maxX - 20
            
            if posX < roadMinX { posX = roadMinX }
            if posX > roadMaxX { posX = roadMaxX }
            
            strongSelf.playerNode.run(.moveTo(x: posX, duration: 0))
        }
    }
    
    func setupNewGameButton() {
        let (button, label) = SKViewFactory().buildNewGameButton(rect: frame)
        addChild(button)
        addChild(label)
    }
    
    private func setupPlayVideoButton() {
        let (button, label) = SKViewFactory().buildPlayVideoButton(rect: frame)
        addChild(button)
        addChild(label)
    }
    
    // MARK: - User Interaction Helpers
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let location = touch.location(in: self)
            
            if let nodeName = self.atPoint(location).name {
                let factory = SKViewFactory()
                switch nodeName {
                case factory.ngLabelKey, factory.ngBtnKey:
                    didTapNewGame()
                case factory.pvLabelKey, factory.pvBtnKey:
                    playVideo()
                default:
                    break
                }
            }
        }
    }
    
    private func didTapNewGame() {
        let scene = GameScene(size: self.size)
        scene.insets = insets
        scene.sceneDelegate = sceneDelegate
        scene.scaleMode = .aspectFit
        self.view?.presentScene(scene)
    }
    
    private func playVideo() {
        self.videoWasPresented = true
        self.sceneDelegate?.scene(self, shouldPresentRewardBasedVideoAd: true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            SKViewFactory().childNodeNames().forEach { (name) in
                self.childNode(withName: name)?.removeFromParent()
            }
            
            self.enumerateChildNodes(withName: Cars().car) { (node, ptr) in
                node.removeFromParent()
            }
        }
    }
    
    // MARK: - RepeatForever Actions

    private func addRoadLine() {
        let size: CGSize = .init(width: 8, height: 50)
        let posY: CGFloat = self.frame.maxY + size.height
        
        var actions = [SKAction]()
        actions.append(.moveTo(
            y: -size.height,
            duration: 2))
        actions.append(.removeFromParent())
        
        if let leftLine = self.roadLineNode.copy() as? SKShapeNode {
            let posX = self.roadNode.frame.minX + self.playerNode.size.width
            leftLine.position = .init(x: posX, y: posY)
            
            DispatchQueue.main.async {
                self.addChild(leftLine)
                leftLine.run(.sequence(actions))
            }
            
            if let rightLine = leftLine.copy() as? SKShapeNode {
                rightLine.position.x = self.roadNode.frame.maxX - self.playerNode.size.width
                
                DispatchQueue.main.async {
                    self.addChild(rightLine)
                    rightLine.run(.sequence(actions))
                }
            }
        }
    }
    
    private func addRandomCar() {        
        var cars = ["car2", "car3", "car4", "car5", "car6", "car7", "car8", "car9"]
        cars.shuffle()
        
        let texture = SKTexture(imageNamed: cars[0])
        texture.size()

        let roadMinX = self.frame.minX + 30
        let roadMaxX = self.frame.maxX - 20
        let randomDist = GKRandomDistribution(lowestValue: Int(roadMinX), highestValue: Int(roadMaxX))
        
        let car = SKSpriteNode(texture: texture)
        car.position = CGPoint(x: CGFloat(randomDist.nextInt()), y: frame.size.height + car.size.height)
        car.name = Cars().car
        car.zPosition = 1
        car.setScale(to: frame.width / 3)
        
        // set physics body of the car
        func buildPhysicsBody(texture: SKTexture) -> SKPhysicsBody {
            let body = SKPhysicsBody(texture: texture, alphaThreshold: 0.1, size: car.size)
            body.isDynamic = false
            body.categoryBitMask = Category.car.rawValue
            body.contactTestBitMask = Category.player.rawValue
            body.collisionBitMask = 0
            return body
        }
    
        if let body = cachedCars[texture] {
            car.physicsBody = (body.copy() as! SKPhysicsBody)
        } else {
            car.physicsBody = buildPhysicsBody(texture: texture)
            
            if car.physicsBody == nil {
                if let rTexture = view?.texture(from: SKSpriteNode(texture: texture)) {
                    car.physicsBody = buildPhysicsBody(texture: rTexture)
                    
                    if car.physicsBody != nil {
                        cachedCars[texture] = car.physicsBody!
                    } else {
                        // Physics body is empty, if game is active dont add car to screen
                        if !remainingLives.isEmpty {
                            return
                        }
                    }
                }
            } else {
                cachedCars[texture] = car.physicsBody!
            }
        }
        
        var actions = [SKAction]()
        actions.append(.moveTo(
            y: -car.size.height / 2,
            duration: 3))

        let increaseScore = SKAction.run {
            if !self.gameOver {
                self.score += 1
            }
        }

        actions.append(increaseScore)
        actions.append(.removeFromParent())
        
        DispatchQueue.main.async {
            self.addChild(car)
            car.run(.sequence(actions))
        }
    }
    
    private func addCoin() {
        let random = Int.random(in: 0...10)
        var randomCoin: SKSpriteNode?
        
        if random >= 0 && random <= 5 {
            randomCoin = self.singleCoin.copy() as? SKSpriteNode
        } else if random > 5 && random <= 8 {
            randomCoin = self.multipleCoins.copy() as? SKSpriteNode
        } else {
            randomCoin = self.coinBag.copy() as? SKSpriteNode
        }
        
        if let coin = randomCoin {
            let roadMinX = self.frame.minX + 30
            let roadMaxX = self.frame.maxX - 20
            
            let randomDist = GKRandomDistribution(
                lowestValue: Int(roadMinX),
                highestValue: Int(roadMaxX))
            
            coin.position.x = CGFloat(randomDist.nextInt())
            
            let body = SKPhysicsBody(circleOfRadius: coin.size.width / 2)
            body.isDynamic = false
            body.categoryBitMask = Category.coin.rawValue
            body.contactTestBitMask = Category.player.rawValue
            body.collisionBitMask = 0
            
            coin.physicsBody = body
            
            var actions = [SKAction]()
            actions.append(.moveTo(
                y: -coin.size.height / 2,
                duration: 3))
            
            actions.append(.removeFromParent())
            
            DispatchQueue.main.async {
                self.addChild(coin)
                coin.run(.sequence(actions))
            }
        }
    }
}

// MARK: - SKPhysicsContactDelegate

extension GameScene: SKPhysicsContactDelegate {
    func didBegin(_ contact: SKPhysicsContact) {
        var fBody: SKPhysicsBody
        var sBody: SKPhysicsBody
        
        if contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask {
            fBody = contact.bodyA
            sBody = contact.bodyB
        } else {
            fBody = contact.bodyB
            sBody = contact.bodyA
        }
        
        if (fBody.categoryBitMask & Category.player.rawValue) != 0
            && (sBody.categoryBitMask & Category.car.rawValue) != 0 {
            if let car = sBody.node as? SKSpriteNode {
                playerDidCollide(withCar: car)
            }
        }
        
        if (fBody.categoryBitMask & Category.player.rawValue) != 0
            && (sBody.categoryBitMask & Category.coin.rawValue) != 0 {
            if let coin = sBody.node as? SKSpriteNode {
                playerDidCollide(withCoin: coin)
            }
        }
    }
    
    fileprivate func playerDidCollide(withCar car: SKSpriteNode) {
        car.removeFromParent()
        
        if let live = remainingLives.last {
            live.removeFromParent()
            remainingLives.removeLast()
        }
        
        if remainingLives.isEmpty {
            endGame()
        }
    }
    
    fileprivate func endGame() {
        self.gameOver = true
        
        let explosion = self.explosionNode.copy() as! SKEmitterNode
        explosion.position = playerNode.position
        self.addChild(explosion)
        
        self.run(explosionSound)
        playerNode.removeFromParent()
        
        self.run(.wait(forDuration: 2)) { [weak self] in
            guard let strongSelf = self else { return }
            explosion.removeFromParent()
            strongSelf.stopGame()
        }
    }
    
    fileprivate func playerDidCollide(withCoin coin: SKSpriteNode) {
        self.run(coinSound)
        coin.removeFromParent()
        
        if let c = Coin(rawValue: coin.name!) {
            score += c.value
        }
    }
}
