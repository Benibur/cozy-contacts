Modal    = require './modal'
Photo    = require '../models/photo'
template = require('../templates/photo-picker-croper')()

module.exports = class PhotoPickerCroper extends Modal

    # Class attributes

    id                : 'objet-picker'
    title             : t 'pick from files'

    # Methods

    events: -> _.extend super,
        'click    .thumbsContainer' : 'validateClick'
        'dblclick .thumbsContainer' : 'validateDblClick'
        'click    a.next'           : 'displayMore'
        'click    a.prev'           : 'displayPrevPage'
        'click    .chooseAgain'     : 'chooseAgain'
        'click    .modal-uploadBtn' : 'changePhotoFromUpload'
        'change   #uploader'        : 'handleFile'
        # 'scroll   .modal-body'      : 'handleScroll'


    initialize: (cb) ->

        @config =
            cssSpaceName    : "objet-picker"
            singleSelection : true # tells if user can select one or more photo
            numPerPage      : 50   # number of thumbs preloaded per request
            yes             : t 'modal ok'
            no              : t 'modal cancel'
            cb              : cb   #will be called by onYes
            target_h        : 100 # height of the img-preview div
            target_w        : 100 # width  of the img-preview div
        super(@config)

        @state =
            currentStep : 'photoPicker' # 2 states : 'croper' & 'photoPicker'
            selected    : {} # selected.photoID = thumb = {id,name,thumbEl}
            selected_n  : 0  # number of photos selected
            skip        : 0  # rank of the oldest downloaded thumb
            percent     : 0  # % of thumbnails computation avancement (if any)
            img_naturalW: 0  # natural width  (px) of the selected file
            img_naturalH: 0  # natural height (px) of the selected file

        body           = @el.querySelector('.modalCY-body')
        body.innerHTML = template

        @body         = body
        @photoPicker  = body.querySelector('.photoPicker')
        @cropper$     = @el.querySelector('.croper')
        @thumbs$      = body.querySelector('.thumbsContainer') # the div containing photos
        @imgToCrop    = @cropper$.querySelector('#img-to-crop')
        @imgPreview   = @cropper$.querySelector('#img-preview')
        @nextBtn      = body.querySelector('.next')
        @uploader     = body.querySelector('#uploader')

        body.classList.add('photoPickerCroper')
        @bindTabs()

        @body.addEventListener('scroll', @handleScroll)
        @imgToCrop.addEventListener('load', @onImgToCropLoaded, false)

        @cropper$.style.display = 'none'
        @addPage(0, @config.numPerPage) # load the first page of thumbs
        @state.skip +=  @config.numPerPage
        return true


    handleScroll: (e) =>
        b = b + 3
        console.log this.target
        # if @body.


    validateDblClick:(e)->
        if e.target.nodeName != "IMG"
            return
        if @config.singleSelection
            if typeof @state.selected[e.target.id] != 'object'
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
        if @config.singleSelection
            currentID = @getSelectedID()
            if currentID == id
                return
            @toggleOne(el, id)
            # unselect other thumbs
            for i, thumb of @state.selected # thumb = {id,name,thumbEl}
                if i != id
                    if typeof(thumb) == 'object' # means thumb is selected
                        $(thumb.el).removeClass('selected')
                        @state.selected[i] = false
                        @state.selected_n -=1
        else
            @toggleOne(el, id)


    selectFirstThumb:()->
        @toggleClicked(@thumbs$.firstChild)


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
        if typeof(@state.selected[id]) == 'object'
            $(thumbEl).removeClass('selected')
            @state.selected[id] = false
            @state.selected_n -=1
        else
            $(thumbEl).addClass('selected')
            @state.selected[id] = {id:id,name:"",el:thumbEl}
            @state.selected_n +=1


    getSelectedID : () ->
        for k, val of @state.selected
            if typeof(val)=='object'
                return k
        return null


    getSelectedThumb : () ->
        for k, val of @state.selected
            if typeof(val)=='object'
                return val.el
        return null


    # supercharge the modal behavour : "ok" leads to the cropping step
    onYes: ()->
        if @state.currentStep == 'photoPicker'
            if @state.selected_n == 1
                @showCropingTool()
            else
                return false
        else
            s = @imgPreview.style
            r = @state.img_naturalW / @imgPreview.width
            d =
                sx      : Math.round(- parseInt(s.marginLeft)*r)
                sy      : Math.round(- parseInt(s.marginTop )*r)
                sWidth  : Math.round(@config.target_h*r)
                sHeight : Math.round(@config.target_w*r)
            @close()
            @cb(true,@getResultDataURL(@imgPreview, d))


    changePhotoFromUpload: () =>
        @uploadPopupOpened = true
        @uploader.click()


    handleFile: () =>
        file = @uploader.files[0]
        unless file.type.match /image\/.*/
            return alert t 'This is not an image'
        reader = new FileReader()
        img = new Image()
        reader.readAsDataURL file
        reader.onloadend = =>
            @showCropingTool(reader.result)


    getResultDataURL:(img, dimensions)->
        IMAGE_DIMENSION = 600

        # use canvas to resize the image
        canvas = document.createElement 'canvas'
        canvas.height = canvas.width = IMAGE_DIMENSION
        ctx = canvas.getContext '2d'
        if dimensions?
            d = dimensions
            ctx.drawImage( img, d.sx, d.sy, d.sWidth,
                           d.sHeight, 0, 0, IMAGE_DIMENSION, IMAGE_DIMENSION)
        return dataUrl =  canvas.toDataURL 'image/jpeg'


    onKeyStroke: (e)->
        # TODO : the modal class methog listening to keystrokes
        # should be named "onKeyStroke"
        if @state.currentStep == 'croper'
            if e.which is 27 # escape key => choose another photo
                e.stopPropagation()
                @chooseAgain()
            else if e.which == 13 # return key => validate modal
                e.stopPropagation()
                @onYes()
                return
            else
                return
        else # @state.currentStep == 'photoPicker'
            switch e.which
                when 27 # escape key
                    # esc in the pop up to choose a file to upload
                    if @uploadPopupOpened
                        @uploadPopupOpened = false
                        e.stopPropagation()
                    # esc in the normal case
                    else
                        return super(e) # will call @cb
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


    addPage:(skip, limit)->
        # Recover files
        Photo.listFromFiles skip, limit, @listFromFiles_cb


    listFromFiles_cb: (err, body) =>
        files = body.files if body?.files?

        if err
            return console.log err

        # If server is creating thumbs : then wait before to display files.
        else if body.percent?
            @state.percent = body.percent
            pathToSocketIO = \
                "#{window.location.pathname.substring(1)}socket.io"
            socket = io.connect window.location.origin,
                resource: pathToSocketIO
            socket.on 'progress', (event) =>
                @state.percent = event.percent
                if @state.percent is 100
                    # TODO
                else
                    # TODO

        # If there is no photos in Cozy
        else if files? and Object.keys(files).length is 0
            @thumbs$.innerHTML = "<p>#{t 'no image'}</p>"

        # there are some images, add thumbs to modal
        else
            if body?.hasNext?
                hasNext = body.hasNext
            else
                hasNext = false
            @addThumbs(body.files, hasNext)
            if @config.singleSelection and @state.selected_n == 0
                @selectFirstThumb()


    addThumbs : (files, hasNext) ->
        # Add next button
        if !hasNext
            @nextBtn.style.display = 'none'
        # dates = Object.keys files
        # dates.sort (a, b) ->
        #     -1 * a.localeCompare b
        frag = document.createDocumentFragment()
        s = ''
        # for month in dates
        #     photos = files[month]
        for p in files
            img       = new Image()
            img.src   = "files/thumbs/#{p.id}.jpg"
            img.id    = "#{p.id}"
            img.title = "#{p.name}"
            frag.appendChild(img)
        @thumbs$.appendChild(frag)


    displayMore: ->
        # Display next page of photo
        @addPage(@state.skip, @config.numPerPage)
        @state.skip +=  @config.numPerPage


    showCropingTool: (dataUrl)->
        @state.currentStep = 'croper'
        @currentPhotoScroll = @body.scrollTop

        @photoPicker.style.display = 'none'
        @cropper$.style.display = ''

        if dataUrl
            screenUrl       = dataUrl
        else
            screenUrl       = "files/screens/#{@getSelectedID()}.jpg"
        @imgToCrop.src  = screenUrl
        @imgPreview.src = screenUrl


    onImgToCropLoaded: ()=>
        img_w  = @imgToCrop.width
        img_h  = @imgToCrop.height
        @img_w = img_w
        @img_h = img_h
        @state.img_naturalW = @imgToCrop.naturalWidth
        @state.img_naturalH = @imgToCrop.naturalHeight
        selection_w   = Math.round(Math.min(img_h,img_w)*1)
        x = Math.round( (img_w-selection_w)/2 )
        y = Math.round( (img_h-selection_w)/2 )
        options =
            onChange    : @updateCropedPreview
            onSelect    : @updateCropedPreview
            aspectRatio : 1
            setSelect   : [ x, y, x+selection_w, y+selection_w ]
        t = this
        $(@imgToCrop).Jcrop( options, ()->
            t.jcrop_api = this
        )
        t.jcrop_api.focus()


    updateCropedPreview: (coords) =>
        prev_w = @img_w / coords.w * @config.target_w
        prev_h = @img_h / coords.h * @config.target_h
        prev_x = @config.target_w  / coords.w * coords.x
        prev_y = @config.target_h  / coords.h * coords.y
        s            = @imgPreview.style
        s.width      = Math.round(prev_w) + 'px'
        s.height     = Math.round(prev_h) + 'px'
        s.marginLeft = '-' + Math.round(prev_x) + 'px'
        s.marginTop  = '-' + Math.round(prev_y) + 'px'
        return true


    chooseAgain : ()->
        @state.currentStep = 'photoPicker'
        @jcrop_api.destroy()
        @imgToCrop.removeAttribute('style')
        @imgToCrop.src = ''
        @photoPicker.style.display = ''
        @cropper$.style.display = 'none'
        @body.scrollTop = @currentPhotoScroll


    bindTabs: ->
        @$('[role=tablist]').on 'click', '[role=tab]', (event) =>
            $panel = @$( ".#{event.target.getAttribute 'aria-controls'}" )
            @$('[role=tabpanel]').not($panel).attr( 'aria-hidden', true )
            $panel.attr 'aria-hidden', false
            @$('nav [role=tab]').attr 'aria-selected', false
            $(event.target).attr 'aria-selected', true
