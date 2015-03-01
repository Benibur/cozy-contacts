Modal    = require 'cozy-clearance/modal'
Photo    = require '../models/photo'
template = require('../templates/photo_browser')()

module.exports = class PhotoPickerCroper extends Modal

    id                : 'photo-picker-croper'
    title             : t 'pick from files'
    thumbsContainer   : null # the div containing photos
    singleSelection   : true # tells if user can select one or more photo
    currentStep       : 'photoPicker' # 2 states : 'croper' & 'photoPicker'
    page       : 0  # highest page requested to the server.
    selected   : {} # selected.photoID = thumb = {id,name,thumbEl}
    selected_n : 0  # number of photos selected
    dates      : "Waiting for photo"
    percent    : 0     # percent of thumbnails computation avancement (if any)
    hasNext    : false # tells if there are more photo to fetch from the server


    events: -> _.extend super,
        'click    .thumbsContainer' : 'validateClick'
        'dblclick .thumbsContainer' : 'validateDblClick'
        'click    a.next'           : 'displayMore'
        'click    a.prev'           : 'displayPrevPage'
        'click    .chooseAgain'     : 'chooseAgain'


    initialize: (cb) ->
        @cb  = cb               #will be called
        @yes = t 'modal ok'
        @no  = t 'modal cancel'
        super({})
        @body              = @el.querySelector('.modal-body')
        body               = @body
        body.innerHTML     = template
        @photoContainer    = body.querySelector('.photoContainer')
        @thumbsContainer   = body.querySelector('.thumbsContainer')
        @croppingEl        = @el.querySelector('.cropping')
        @imgToCrop         = @croppingEl.querySelector('#img-to-crop')
        @imgPreview        = @croppingEl.querySelector('#img-preview')
        @nextBtn           = body.querySelector('.next')
        @target_h          = 100 # height of the img-preview div
        @target_w          = 100 # width  of the img-preview div
        @img_naturalW      = 0   # number of pixels of the file selected
        @img_naturalH      = 0   # number of pixels of the file selected

        body.classList.add('photoPickerCroper')
        @imgToCrop.addEventListener('load', @onImgToCropLoaded, false)
        @croppingEl.style.display = 'none'  #hide the croping area
        @addPage(0)
        return true


    validateDblClick:(e)->
        if e.target.nodeName != "IMG"
            return
        if @singleSelection
            if typeof @.selected[e.target.id] != 'object'
                @toggleClicked(e.target)
            @showCropingTool()
        else
            return


    validateClick:(e)->
        el = e.target
        if el.nodeName != "IMG"
            return
        @toggleClicked(el)


    toggleClicked: (el) ->
        id = el.id
        if @singleSelection
            currentID = @getSelectedID()
            if currentID == id
                return
            @toggleOne(el, id)
            # unselect other thumbs
            for i, thumb of @.selected # thumb = {id,name,thumbEl}
                if i != id
                    if typeof(thumb) == 'object' # means thumb is selected
                        $(thumb.el).removeClass('selected')
                        @.selected[i] = false
                        @.selected_n -=1
        else
            @toggleOne(el, id)


    selectFirstThumb:()->
        @toggleClicked(@thumbsContainer.firstChild)


    selectNextThumb: ()->
        thumb = @getSelectedThumb()
        if thumb == null
            return
        nextThumb = thumb.nextElementSibling
        if nextThumb
            @toggleClicked(nextThumb)


    selectPreviousThumb : ()->
        thumb = @getSelectedThumb()
        if thumb == null
            return
        prevThumb = thumb.previousElementSibling
        if prevThumb
            @toggleClicked(prevThumb)


    selectThumbUp : ()->
        thumb = @getSelectedThumb()
        if thumb == null
            return
        x = thumb.x
        prevThumb = thumb.previousElementSibling
        while prevThumb
            if prevThumb.x == x
                @toggleClicked(prevThumb)
                return
            prevThumb = prevThumb.previousElementSibling
        firstThumb = thumb.parentElement.firstChild
        if firstThumb != thumb
            @toggleClicked(firstThumb)


    selectThumbDown : ()->
        thumb = @getSelectedThumb()
        if thumb == null
            return
        x = thumb.x
        nextThumb = thumb.nextElementSibling
        while nextThumb
            if nextThumb.x == x
                @toggleClicked(nextThumb)
                return
            nextThumb = nextThumb.nextElementSibling
        lastThumb = thumb.parentElement.lastChild
        if lastThumb != thumb
            @toggleClicked(lastThumb)


    toggleOne: (thumbEl, id) ->
        if typeof(@.selected[id]) == 'object'
            $(thumbEl).removeClass('selected')
            @.selected[id] = false
            @.selected_n -=1
        else
            $(thumbEl).addClass('selected')
            @.selected[id] = {id:id,name:"",el:thumbEl}
            @.selected_n +=1


    getSelectedID : () ->
        for k, val of @.selected
            if typeof(val)=='object'
                return k
        return null


    getSelectedThumb : () ->
        for k, val of @.selected
            if typeof(val)=='object'
                return val.el
        return null


    # supercharge the modal behavour : "ok" leads to the cropping step
    onYes: ()->
        if @currentStep == 'photoPicker'
            if @.selected_n == 1
                @showCropingTool()
            else
                return false
        else
            s = @imgPreview.style
            r = @img_naturalW / @imgPreview.width
            d =
                sx      : Math.round(- parseInt(s.marginLeft)*r)
                sy      : Math.round(- parseInt(s.marginTop )*r)
                sWidth  : Math.round(@target_h*r)
                sHeight : Math.round(@target_w*r)
            @close()
            @cb(true,@imgPreview, d)


    closeOnEscape: (e)->
        # TODO : the modal class methog listening to keystrokes
        # should be named "onKeyStroke"
        if @currentStep == 'croper'
            if e.which is 27 # escape key => choose another photo
                e.stopPropagation()
                @chooseAgain()
            else if e.which == 13 # return key => validate modal
                e.stopPropagation()
                @onYes()
                return
            else
                return
        else # @currentStep == 'croper'
            switch e.which
                when 27 # escape key
                    return super(e)
                when 13 # return key
                    e.stopPropagation()
                    @onYes()
                    return
                when 39 # right key
                    e.stopPropagation()
                    @selectNextThumb()
                when 37 # left key
                    e.stopPropagation()
                    @selectPreviousThumb()
                when 38 # up key
                    e.stopPropagation()
                    @selectThumbUp()
                when 40 # down key
                    e.stopPropagation()
                    @selectThumbDown()
                else
                    return
        return


    addPage:(page)->
        # Recover files
        Photo.listFromFiles page, @listFromFiles_cb


    listFromFiles_cb: (err, body) =>
        files = body.files if body?.files?

        if err
            return console.log err

        # If server is creating thumbs : then wait before to display files.
        else if body.percent?
            @.dates   = "Thumb creation"
            @.percent = body.percent
            pathToSocketIO = \
                "#{window.location.pathname.substring(1)}socket.io"
            socket = io.connect window.location.origin,
                resource: pathToSocketIO
            socket.on 'progress', (event) =>
                @.percent = event.percent
                if @.percent is 100
                    # TODO
                else
                    # TODO

        # If there is no photos in Cozy
        else if files? and Object.keys(files).length is 0
            @thumbsContainer.innerHTML = "<p>#{t 'no image'}</p>"

        # there are some images, add thumbs to modal
        else
            if body?.hasNext?
                hasNext = body.hasNext
            else
                hasNext = false
            @addThumbs(body.files, hasNext)
            if @singleSelection
                @selectFirstThumb()


    addThumbs : (files, hasNext) ->
        # Add next button
        if !hasNext
            @nextBtn.style.display = 'none'
        dates = Object.keys files
        dates.sort (a, b) ->
            -1 * a.localeCompare b
        frag = document.createDocumentFragment()
        s = ''
        for month in dates
            photos = files[month]
            for p in photos
                img       = new Image()
                img.src   = "files/thumbs/#{p.id}.jpg"
                img.id    = "#{p.id}"
                img.title = "#{p.name}"
                frag.appendChild(img)
        @thumbsContainer.appendChild(frag)


    displayMore: ->
        # Display next page of photo
        @.page +=  1
        @addPage(@.page)


    showCropingTool:->
        @currentStep = 'croper'
        @currentPhotoScroll = @body.scrollTop

        @photoContainer.style.display = 'none'
        @croppingEl.style.display = ''

        screenUrl       = "files/screens/#{@getSelectedID()}.jpg"
        @imgToCrop.src  = screenUrl
        @imgPreview.src = screenUrl


    onImgToCropLoaded: ()=>
        img_w  = @imgToCrop.width
        img_h  = @imgToCrop.height
        @img_w = img_w
        @img_h = img_h
        @img_naturalW = @imgToCrop.naturalWidth
        @img_naturalH = @imgToCrop.naturalHeight
        selection_w   = Math.round(Math.min(img_h,img_w)*1)
        x = Math.round( (img_w-selection_w)/2 )
        y = Math.round( (img_h-selection_w)/2 )
        options =
            onChange    : @updatePreview
            onSelect    : @updatePreview
            aspectRatio : 1
            setSelect   : [ x, y, x+selection_w, y+selection_w ]
        t = this
        $(@imgToCrop).Jcrop( options, ()->
            t.jcrop_api = this
        )


    updatePreview: (coords) =>
        prev_w = @img_w / coords.w * @target_w
        prev_h = @img_h / coords.h * @target_h
        prev_x = @target_w  / coords.w * coords.x
        prev_y = @target_h / coords.h * coords.y

        s            = @imgPreview.style
        s.width      = Math.round(prev_w) + 'px'
        s.height     = Math.round(prev_h) + 'px'
        s.marginLeft = '-' + Math.round(prev_x) + 'px'
        s.marginTop  = '-' + Math.round(prev_y) + 'px'
        return true


    chooseAgain : ()->
        @currentStep = 'photoPicker'
        @jcrop_api.destroy()
        @imgToCrop.removeAttribute('style')
        @imgToCrop.src = ''
        croppingEl = @el.querySelector('.cropping')
        @photoContainer.style.display = ''
        croppingEl.style.display = 'none'
        @body.scrollTop = @currentPhotoScroll



