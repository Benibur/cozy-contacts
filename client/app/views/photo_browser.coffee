Modal = require 'cozy-clearance/modal'
Photo = require '../models/photo'


module.exports = class FilesBrowser extends Modal

    id: 'files-browser-modal'
    template_content: require '../templates/photo_browser'
    title: t 'pick from files'
    content: '<p>Loading ...</p>'

    events: -> _.extend super,
        'click img': 'toggleSelected'
        'click a.next': 'displayNextPage'
        'click a.prev': 'displayPrevPage'
        'click #crop-req-btn' : 'showCropingTool'

    toggleSelected: (e) ->
        $(e.target).toggleClass 'selected'

    getRenderData: -> @options

    initialize: (options) ->
        @yes = t 'modal ok'
        @no = t 'modal cancel'

        # Prepare option
        if not options.page?
            super {}

        if not options.page?
            options.page = 0

        @options = {}  # BJA : à quoi sert @option ? je l'initialise ici pour ne pas planter... à supprimer
        if not options.selected?
            @options.selected = []

        @options.page = options.page


        # Recover files
        Photo.listFromFiles options.page, (err, body) =>
            dates = body.files if body?.files?

            if err
                return console.log err

            # If server create thumb : doesn't display files.
            else if body.percent?
                @options.dates = "Thumb creation"
                @options.percent = body.percent
                pathToSocketIO = \
                    "#{window.location.pathname.substring(1)}socket.io"
                socket = io.connect window.location.origin,
                    resource: pathToSocketIO
                socket.on 'progress', (event) =>
                    @options.percent = event.percent
                    if @options.percent is 100
                        @initialize options
                    else
                        template = @template_content @getRenderData()
                        @$('.modal-body').html template

            # If there is no photos in Cozy
            else if dates? and Object.keys(dates).length is 0
                @options.dates = "No photos found"

            else
                # Add next/prev button
                @options.hasNext = body.hasNext if body?.hasNext?
                @options.hasPrev = options.page isnt 0
                @options.dates = Object.keys dates
                @options.dates.sort (a, b) ->
                    -1 * a.localeCompare b
                @options.photos = dates

            @$('.modal-body').html @template_content @getRenderData()
            @$('.modal-body').scrollTop(0)

            # CROPPING OF PHOTO
            showPreview = (coords) ->
                target_h = 100 # height of the frame-img-preview
                target_w = 100
                # todo BJA :
                # récupérer la largeur réelle de l'image affichée qui peut varier (fichier petit ou paysage ou portrait...)
                # ATTENTION il faut récupérer la dimention AFFICHEE, c'est à dire le nbr de px à l'écran, pas le nbr de px dans le fichier. d'origine)
                img_w = 300
                img_h = 241

                prev_w = img_w / coords.w * target_w
                prev_h = img_h / coords.h * target_h
                prev_x = target_w / coords.w  * coords.x
                prev_y = target_h / coords.h * coords.y

                $('#img-preview').css(
                    width: Math.round(prev_w ) + 'px',
                    height: Math.round(prev_h ) + 'px',
                    marginLeft: '-' + Math.round(prev_x) + 'px',
                    marginTop: '-' + Math.round(prev_y ) + 'px'
                )
            $('#img-to-crop').Jcrop(
                onChange: showPreview
                onSelect: showPreview
                aspectRatio: 1
                setSelect:   [ 10, 10, 150, 150 ]
            )
            #hide the croping area
            @$('.cropping').hide()
            # $('.files').hide()  # TODO BJA : uniquement pour faciliter les tests

            # Add selected files
            if @options.selected[@options.page]?
                for img in @options.selected[@options.page]
                    @$("##{img.id}").toggleClass 'selected'

    cb: (confirmed) ->
        return unless confirmed
        @options.beforeUpload (attrs) =>
            tmp = []
            @options.selected[@options.page] = @$('.selected')
            for page in @options.selected
                for img in page
                    fileid = img.id

                    # Create a temporary photo
                    attrs.title = img.name
                    phototmp = new Photo attrs
                    phototmp.file = img
                    tmp.push phototmp
                    @collection.add phototmp

                    Photo.makeFromFile fileid, attrs, (err, photo) =>
                        return console.log err if err
                        # Replace temporary photo
                        phototmp = tmp.pop()
                        @collection.remove phototmp, parse: true
                        @collection.add photo, parse: true

    displayNextPage: ->
        # Display next page: store selected files
        @options.selected[@options.page] = @$('.selected')
        options =
            page: @options.page + 1
            selected: @options.selected
        @initialize options

    displayPrevPage: ->
        # Display prev page: store selected files
        @options.selected[@options.page] = @$('.selected')
        options =
            page: @options.page - 1
            selected: @options.selected
        @initialize options

    showCropingTool:->
        @$('.files').hide()
        @$('.croping').show()