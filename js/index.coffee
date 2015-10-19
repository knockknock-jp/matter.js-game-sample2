$ ->

  $window = $(window)
  $html = $("html")
  $body = $("body")

  engine = {} unless engine?
  view = {} unless view?

  ###
  定数
  ###

  FPS = 1000 / 30
  ID_SCENE_INTRO = "id_scene_intro"
  ID_SCENE_GAME = "id_scene_game"
  ID_SCENE_OUTRO = "id_scene_outro"
  SCROLL_SPEED = 5
  STAGE_WIDTH = 750
  STAGE_HEIGHT = 750
  STAGE_DEPTH = 375
  OBSTACLE_HEIGHT = 750
  OBSTACLE_WIDTH = 100
  OBSTACLE_DURATION_X = 300
  OBSTACLE_DURATION_Y = 200
  PLAYER_HEIGHT = 49
  PLAYER_WIDTH = 34
  PLAYER_JUMP_FORCE = 0.11
  ID_SOUND_CLICK = "js-soundClick"
  ID_SOUND_FAILURE = "js-soundFailure"
  ID_SOUND_JUMP = "js-soundJump"
  ID_SOUND_COUNTUP = "js-soundCountUp"

  ###
  クラス
  ###

  # メイン
  class Main
    constructor: ->
      @_engine = null
      @_view = null
      @_panel = null
      @_sound = null
      @_currentSceneId = null
      @_count = 0
      # シーン変更イベント
      $body.on "changeSceneEvent", (e, data)=>
        if data.id is ID_SCENE_INTRO
          if @_currentSceneId is ID_SCENE_INTRO
            return
          @_currentSceneId = ID_SCENE_INTRO
          # イントロシーン開始
          @_engine.setIntroScene()
          @_panel.setIntroScene()
        else if data.id is ID_SCENE_GAME
          if @_currentSceneId is ID_SCENE_GAME
            return
          @_currentSceneId = ID_SCENE_GAME
          # ゲームシーン開始
          @_engine.setGameScene()
          @_panel.setGameScene()
          # カウント初期化
          @_count = 0
          @_panel.setCount @_count
          # 効果音再生イベント
          $body.trigger "playSoundEvent", [{id: ID_SOUND_CLICK}]
        else if data.id is ID_SCENE_OUTRO
          if @_currentSceneId is ID_SCENE_OUTRO
            return
          @_currentSceneId = ID_SCENE_OUTRO
          # アウトロシーン開始
          @_engine.setOutroScene()
          @_panel.setOutroScene()
      # カウントアップ
      $body.on "addCountEvent", =>
        @_count = @_count + 1
        @_panel.setCount @_count
        # 効果音再生イベント
        $body.trigger "playSoundEvent", [{id: ID_SOUND_COUNTUP}]
      # 効果音再生イベント
      $body.on "playSoundEvent", (e, data)=>
        if data.id is ID_SOUND_CLICK
          @_sound.play ID_SOUND_CLICK
        else if data.id is ID_SOUND_FAILURE
          @_sound.play ID_SOUND_FAILURE
        else if data.id is ID_SOUND_JUMP
          @_sound.play ID_SOUND_JUMP
        else if data.id is ID_SOUND_COUNTUP
          @_sound.play ID_SOUND_COUNTUP
      # 位置更新イベント
      $body.on "updatePositionEvent", (e, data)=>
        # 位置更新
        @_view.updatePosition data

    # 開始
    start: ->
      # エンジン
      @_engine = new engine.Engine "js-engine"
      # 表示
      @_view = new view.View "js-view"
      # パネル
      @_panel = new Panel()
      # サウンド
      @_sound = new Sound()
      # シーン変更
      $body.trigger "changeSceneEvent", [{id: ID_SCENE_INTRO}]

    # 画面タップ
    onTapScreen: ->
      if @_currentSceneId is ID_SCENE_INTRO
        # シーン変更
        $body.trigger "changeSceneEvent", [{id: ID_SCENE_GAME}]
      else if @_currentSceneId is ID_SCENE_GAME
        # プレーヤージャンプ
        @_engine.jumpPlayer()
        @_view.jumpPlayer()
      else if @_currentSceneId is ID_SCENE_OUTRO
        # 初期化
        @_engine.initialize()
        # シーン変更
        $body.trigger "changeSceneEvent", [{id: ID_SCENE_GAME}]

  # エンジン
  class engine.Engine
    constructor: (element)->
      @_engine = null
      @_player = null
      @_obstacleArr = []
      @_scrollX = 0
      @_scrollTotal = 0
      @_isHit = false
      @_intervalId = null
      @_intervalId2 = null
      # 物理エンジンを作成
      @_engine = Matter.Engine.create document.getElementById(element), {
        render: { # レンダリングの設定
          visible: false
        }
      }
      # 物理シュミレーションを実行
      Matter.Engine.run @_engine
      # 天井生成
      ceiling = Matter.Bodies.rectangle(STAGE_WIDTH / 2, -10, STAGE_WIDTH * 2, 10, {
        isStatic: true # 固定するか否か
      })
      # 床生成
      floor = Matter.Bodies.rectangle(STAGE_WIDTH / 2, STAGE_HEIGHT + 10, STAGE_WIDTH * 2, 10, {
        isStatic: true # 固定するか否か
      })
      # 天井・床追加
      Matter.World.add @_engine.world, [ceiling, floor]
      #
      setInterval ()=>
        params = {}
        if @_player
          params.player = {
            x: @_player.getPositionX()
            y: @_player.getPositionY()
            angle: @_player.getAngle()
          }
        params.obstacleArr = []
        for obstacle in @_obstacleArr
          params.obstacleArr.push({
              id: obstacle.getId().top
              x: obstacle.getPositionX()
              y: obstacle.getPositionY().top
            }
          )
          params.obstacleArr.push({
              id: obstacle.getId().bottom
              x: obstacle.getPositionX()
              y: obstacle.getPositionY().bottom
            }
          )
        params.scroll = @_scrollTotal
        # 位置更新イベント
        $body.trigger "updatePositionEvent", [params]
      , FPS

    # イントロシーン開始
    setIntroScene: ->
      # エンジン停止
      @_engine.enabled = false
      @_scrollTotal = 0

    # ゲームシーン開始
    setGameScene: ->
      # エンジン再起動
      @_engine.enabled = true
      # プレーヤー生成
      @_player = new engine.Player @_engine.world
      # 障害物生成
      @_obstacleArr.push new engine.Obstacle(@_engine.world)
      @_isHit = false
      if @_intervalId
        clearInterval @_intervalId
      @_intervalId = setInterval =>
        @_scrollX += SCROLL_SPEED
        @_scrollTotal += SCROLL_SPEED
        if OBSTACLE_DURATION_X < @_scrollX
          @_scrollX = 0
          # 障害物生成
          @_obstacleArr.push new engine.Obstacle(@_engine.world)
        arr = []
        for obstacle in @_obstacleArr
          if obstacle.getPositionX() < -((OBSTACLE_WIDTH) / 2 + 100)
            # 障害物削除
            obstacle.remove()
            obstacle = null
          else
            # 障害物更新
            obstacle.update()
            arr.push obstacle
            # 障害物通過判定
            if obstacle.getIsPast(@_player.getPositionX())
              # カウントアップイベント
              $body.trigger "addCountEvent"
        @_obstacleArr = arr
      , FPS
      # 衝突判定
      Matter.Events.on @_engine, "collisionStart", @_onHit

    # 終了シーン開始
    setOutroScene: ->
      # エンジン停止
      @_engine.enabled = false

    # 初期化
    initialize: ->
      if @_player
        @_player.remove()
        @_player = null
      for obstacle in @_obstacleArr
        obstacle.remove()
      @_obstacleArr = []
      @_scrollX = 0
      @_scrollTotal = 0

    # プレーヤージャンプ
    jumpPlayer: ->
      if @_isHit
        return
      # ジャンプ
      @_player.jump()

    _onHit: (e)=>
      if @_intervalId
        clearInterval @_intervalId
      # 衝突判定
      Matter.Events.off @_engine, "collisionStart", @_onHit
      @_isHit = true
      if @_intervalId2
        clearInterval @_intervalId2
      @_intervalId2 = setTimeout =>
        clearTimeout @_intervalId2
        # シーン変更
        $body.trigger "changeSceneEvent", [{id: ID_SCENE_OUTRO}]
      , 2000
      # 効果音再生イベント
      $body.trigger "playSoundEvent", [{id: ID_SOUND_FAILURE}]

  # プレーヤー（エンジン用）
  class engine.Player
    constructor: (world)->
      @_world = world
      @_body = null
      @_intervalId = null
      # Body生成
      @_body = Matter.Bodies.rectangle(STAGE_WIDTH / 2, (STAGE_HEIGHT / 2) - 100, PLAYER_WIDTH, PLAYER_HEIGHT, {
        isStatic: false # 固定するか否か
        density: 0.002 # 密度
        frictionAir: 0 # 空気抵抗
        render: { # レンダリングの設定
          visible: false
        }
      })
      # Body追加
      Matter.World.add @_world, [@_body]

    # X位置取得
    getPositionX: ->
      return @_body.position.x

    # Y位置取得
    getPositionY: ->
      return @_body.position.y

    # 回転取得
    getAngle: ->
      return @_body.angle

    # ジャンプ
    jump: ->
      # Body上方向に力を加える
      Matter.Body.applyForce @_body, {x: 0, y: 1}, {x: 0, y: -PLAYER_JUMP_FORCE}
      # スプライト変更
      @_body.render.sprite.texture = "./images/gesso2.png"
      if @_intervalId
        clearTimeout @_intervalId
      @_intervalId = setTimeout =>
        @_body.render.sprite.texture = "./images/gesso.png"
      , 100
      # 効果音再生イベント
      $body.trigger "playSoundEvent", [{id: ID_SOUND_JUMP}]

    # 削除
    remove: ->
      # Body削除
      Matter.World.remove @_world, @_body

  # 障害物（エンジン用）
  class engine.Obstacle
    constructor: (world, x)->
      @_world = world
      @_topBody = null
      @_bottomBody = null
      @_isPast = false
      #
      durationY = OBSTACLE_DURATION_Y / 2
      randomY = Math.floor(Math.random() * (STAGE_HEIGHT - OBSTACLE_DURATION_Y) - ((STAGE_HEIGHT - OBSTACLE_DURATION_Y) / 2))
      targetX = STAGE_WIDTH + (OBSTACLE_WIDTH / 2) + 100
      # 上のBody生成
      targetY = (OBSTACLE_HEIGHT / 2) + (-STAGE_HEIGHT / 2) - durationY + randomY
      @_topBody = Matter.Bodies.rectangle(targetX, targetY, OBSTACLE_WIDTH, OBSTACLE_HEIGHT, {
        isStatic: true
        render: { # レンダリングの設定
          visible: false
        }
      })
      # 下のBody生成
      targetY = (OBSTACLE_HEIGHT / 2) + (STAGE_HEIGHT / 2) + durationY + randomY
      @_bottomBody = Matter.Bodies.rectangle(targetX, targetY, OBSTACLE_WIDTH, OBSTACLE_HEIGHT, {
        isStatic: true
        render: { # レンダリングの設定
          visible: false
        }
      })
      # Body追加
      Matter.World.add @_world, [@_topBody, @_bottomBody]

    # 通過判定
    getIsPast: (playerX)->
      if not @_isPast and @_topBody.position.x <= playerX
        @_isPast = true
        return true
      else
        return false

    # X位置取得
    getPositionX: ->
      return @_topBody.position.x

    # Y位置取得
    getPositionY: ->
      return {
        top: @_topBody.position.y
        bottom: @_bottomBody.position.y
      }

    # ID取得
    getId: ->
      return {
        top: @_topBody.id
        bottom: @_bottomBody.id
      }

    # 更新
    update: ->
      # Body移動
      Matter.Body.translate @_topBody, {x: -SCROLL_SPEED, y: 0}
      Matter.Body.translate @_bottomBody, {x: -SCROLL_SPEED, y: 0}

    # 削除
    remove: ->
      # Body削除
      Matter.World.remove @_world, @_topBody
      Matter.World.remove @_world, @_bottomBody

  # 表示
  class view.View
    constructor: (element)->
      @_scene = null
      @_camera = null
      @_renderer = null
      @_intervalId
      @_player = null
      @_ceiling = null
      @_floor = null
      @_obstacleArr = []
      # シーン
      @_scene = new THREE.Scene()
      # 背景
      geometry = new THREE.PlaneGeometry STAGE_WIDTH, STAGE_HEIGHT
      texture = new THREE.ImageUtils.loadTexture "./images/bg.png"
      material = new THREE.MeshBasicMaterial {
        map: texture
      }
      plane = new THREE.Mesh geometry, material
      plane.castShadow = false;
      plane.position.set 0, 0, -STAGE_DEPTH / 2
      @_scene.add plane
      # 天井
      geometry = new THREE.PlaneGeometry STAGE_WIDTH * 2, STAGE_DEPTH
      texture = new THREE.ImageUtils.loadTexture "./images/floor.png"
      texture.wrapS = texture.wrapT = THREE.RepeatWrapping
      texture.repeat.set 40, 20
      material = new THREE.MeshBasicMaterial {
        map: texture
      }
      @_ceiling = new THREE.Mesh geometry, material
      @_ceiling.castShadow = false;
      @_ceiling.position.set 0, STAGE_HEIGHT / 2, 0
      @_ceiling.rotation.x = 90 * Math.PI / 180
      @_scene.add @_ceiling
      # 床
      geometry = new THREE.PlaneGeometry STAGE_WIDTH * 2, STAGE_DEPTH
      texture = new THREE.ImageUtils.loadTexture "./images/floor.png"
      texture.wrapS = texture.wrapT = THREE.RepeatWrapping
      texture.repeat.set 40, 20
      material = new THREE.MeshBasicMaterial {
        map: texture
      }
      @_floor = new THREE.Mesh geometry, material
      @_floor.castShadow = false;
      @_floor.position.set 0, -STAGE_HEIGHT / 2, 0
      @_floor.rotation.x = -90 * Math.PI / 180
      @_scene.add @_floor
      # カメラ
      @_camera = new THREE.PerspectiveCamera 60, STAGE_WIDTH / STAGE_HEIGHT, 1, STAGE_DEPTH * 2
      @_camera.position.set 0, 0, STAGE_DEPTH * 1.5
      # レンダラー
      @_renderer = new THREE.WebGLRenderer {
        antialias: false
      }
      @_renderer.shadowMapEnabled = false
      @_renderer.setSize STAGE_WIDTH, STAGE_HEIGHT
      @_renderer.setClearColor 0x4f7eff, 1
      #
      document.getElementById(element).appendChild @_renderer.domElement
      #
      @_intervalId = setInterval =>
        @_renderer.render @_scene, @_camera
      , FPS

    # 位置更新
    updatePosition: (params)->
      # プレーヤーの追加と位置更新
      if params.player
        if not @_player
          # プレーヤー追加
          @_player = new view.Player @_scene
        playerX = params.player.x - (STAGE_WIDTH / 2) || 0
        playerY = -(params.player.y - (STAGE_HEIGHT / 2)) || 0
        playerAngle = -params.player.angle || 0
        # プレーヤー位置更新
        @_player.setPosition playerX, playerY, playerAngle
        # カメラ位置変更
        @_camera.position.y = playerY * 0.4
      else if not params.player
        if @_player
          # プレーヤー削除
          @_player.remove()
          @_player = null
      # 障害物の追加と位置更新
      for obstacleInfo in params.obstacleArr
        obstacleX = obstacleInfo.x - (STAGE_WIDTH / 2) || 0
        obstacleY = -(obstacleInfo.y - (STAGE_HEIGHT / 2)) || 0
        isExist = false
        for obstacle in @_obstacleArr
          if obstacleInfo.id is obstacle.getId()
            isExist = true
            # 障害物位置更新
            obstacle.setPosition obstacleX, obstacleY
        if not isExist
          # 障害物追加
          obstacle = new view.Obstacle @_scene, obstacleInfo.id
          # 障害物位置更新
          obstacle.setPosition obstacleX, obstacleY
          @_obstacleArr.push obstacle
      # 障害物の削除
      arr = []
      isExist = false
      for obstacle in @_obstacleArr
        for obstacleInfo in params.obstacleArr
          if obstacleInfo.id is obstacle.getId()
            isExist = true
        if isExist
          arr.push obstacle
        else
          # 障害物の削除
          obstacle.remove()
      @_obstacleArr = arr
      # 床と天井のスクロール
      @_floor.position.x = -(params.scroll % (STAGE_WIDTH / 4))
      @_ceiling.position.x = -(params.scroll % (STAGE_WIDTH / 4))

    # プレーヤージャンプ
    jumpPlayer: ->
      @_player.jump()

  # プレーヤー（表示用）
  class view.Player
    constructor: (scene)->
      @_scene = scene
      @_mesh = null
      @_texture = null
      @_intervalId = null
      #
      geometry = new THREE.PlaneGeometry PLAYER_WIDTH, PLAYER_HEIGHT
      @_texture = new THREE.ImageUtils.loadTexture "./images/gesso.png"
      @_texture.wrapS = @_texture.wrapT = THREE.RepeatWrapping
      @_texture.repeat.set 1 / 2, 1
      @_texture.offset.x = 1
      material = new THREE.MeshBasicMaterial {
        map: @_texture
      }
      material.transparent = true
      @_mesh = new THREE.Mesh geometry, material
      @_mesh.castShadow = false
      @_scene.add @_mesh

    # 状態設定
    setPosition: (x, y, rotation)->
      @_mesh.position.set x, y, 0
      @_mesh.rotation.z = rotation

    # ジャンプ
    jump: ->
      @_texture.offset.x = 1 / 2
      if @_intervalId
        clearTimeout @_intervalId
      @_intervalId = setTimeout =>
        @_texture.offset.x = 1
      , 100

    # 削除
    remove: ->
      @_scene.remove @_mesh
      @_mesh = null

  # 障害物（表示用）
  class view.Obstacle
    constructor: (scene, id)->
      @_scene = scene
      @_id = id
      @_mesh = null
      #
      geometry = new THREE.CylinderGeometry OBSTACLE_WIDTH / 2.5, OBSTACLE_WIDTH / 2.5, OBSTACLE_HEIGHT - 20, 16, 1, true
      mesh = new THREE.Mesh geometry
      #
      geometry = new THREE.TorusGeometry (OBSTACLE_WIDTH / 2) - 10, 20, 16, 16
      mesh2 = new THREE.Mesh geometry
      mesh2.rotation.x = Math.PI / 2
      mesh2.rotation.z = Math.PI / 2
      mesh2.position.set 0, (OBSTACLE_HEIGHT / 2) - 20, 0
      #
      mesh3 = new THREE.Mesh geometry
      mesh3.rotation.x = Math.PI / 2
      mesh3.rotation.z = Math.PI / 2
      mesh3.position.set 0, -(OBSTACLE_HEIGHT / 2) + 20, 0
      # ジオメトリ結合
      geometry = new THREE.Geometry()
      THREE.GeometryUtils.merge geometry, mesh
      THREE.GeometryUtils.merge geometry, mesh2
      THREE.GeometryUtils.merge geometry, mesh3
      texture = new THREE.ImageUtils.loadTexture "./images/clay-pipe.png"
      material = new THREE.MeshBasicMaterial {
        map: texture
      }
      @_mesh = new THREE.Mesh geometry, material
      @_mesh = new THREE.Mesh geometry, material
      @_mesh.castShadow = false
      #
      @_scene.add @_mesh

    # ID取得
    getId: ->
      return @_id

    # 状態設定
    setPosition: (x, y)->
      @_mesh.position.set x, y, 0

    # 削除
    remove: ->
      @_scene.remove @_mesh
      @_mesh = null

  # パネル
  class Panel
    constructor: ->
      @_$panelIntro = $ "#js-panelIntro"
      @_$panelGame = $ "#js-panelGame"
      @_$panelOutro = $ "#js-panelOutro"

    # イントロシーン開始
    setIntroScene: ->
      @_$panelIntro.css {
        display: "block"
      }
      @_$panelGame.css {
        display: "none"
      }
      @_$panelOutro.css {
        display: "none"
      }

    # ゲームシーン開始
    setGameScene: ->
      @_$panelIntro.css {
        display: "none"
      }
      @_$panelGame.css {
        display: "block"
      }
      @_$panelOutro.css {
        display: "none"
      }

    # 終了シーン開始
    setOutroScene: ->
      @_$panelIntro.css {
        display: "none"
      }
      @_$panelGame.css {
        display: "block"
      }
      @_$panelOutro.css {
        display: "block"
      }

    # カウント設定
    setCount: (num)->
      @_$panelGame.text num

  # サウンド
  class Sound
    constructor: ->
      @_$soundClick = $("#" + ID_SOUND_CLICK)
      @_$soundFailure = $("#" + ID_SOUND_FAILURE)
      @_$soundJump = $("#" + ID_SOUND_JUMP)
      @_$soundCountUp = $("#" + ID_SOUND_COUNTUP)

    play: (id)->
      target = null
      if id is ID_SOUND_CLICK
        target = @_$soundClick.get(0)
      else if id is ID_SOUND_FAILURE
        target = @_$soundFailure.get(0)
      else if id is ID_SOUND_JUMP
        target = @_$soundJump.get(0)
      else if id is ID_SOUND_COUNTUP
        target = @_$soundCountUp.get(0)
      target.currentTime = 0
      target.volume = 0.2
      target.play()

  ###
  アクション
  ###

  $html.on "keydown", ->
    main.onTapScreen()

  $body.on "touchstart", ->
    main.onTapScreen()

  onResize = =>
    if $window.height() < $window.width()
      size = $window.height()
    else
      size = $window.width()
    $("#js-game").css {
      position: "absolute"
      top: Math.floor(($window.height() - size) / 2)
      left: Math.floor(($window.width() - size) / 2)
      height: size
      width: size
    }
    $("#js-panelIntro").css {
      position: "absolute"
      top: Math.floor((size - 100) / 2)
      left: Math.floor((size - 300) / 2)
    }
    $("#js-panelGame").css {
      position: "absolute"
      top: 20
      left: Math.floor((size - 100) / 2)
    }
    $("#js-panelOutro").css {
      position: "absolute"
      top: Math.floor((size - 100) / 2)
      left: Math.floor((size - 300) / 2)
    }
  onResize()
  $(window).on "resize", onResize

  main = new Main()
  main.start()