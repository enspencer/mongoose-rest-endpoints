express = require 'express'
bodyParser = require 'body-parser'
methodOverride = require 'method-override'
request = require 'supertest'
should = require 'should'
Q = require 'q'

mongoose = require 'mongoose'

moment = require 'moment'

require('../lib/log').verbose(true)
mre = require '../lib/endpoint'
# Custom "Post" and "Comment" documents

commentSchema = new mongoose.Schema
	comment:String
	otherField:Number
	_post:
		type:mongoose.Schema.Types.ObjectId
		ref:'Post'
	_author:
		type:mongoose.Schema.Types.ObjectId
		ref:'Author'


postSchema = new mongoose.Schema
	date:Date
	number:Number
	string:
		type:String
		required:true
	_comments:[
			type:mongoose.Schema.Types.ObjectId
			ref:'Comment'
			$through:'_post'
	]
	otherField:mongoose.Schema.Types.Mixed 

authorSchema = new mongoose.Schema
	name:'String'

# Custom middleware for testing
requirePassword = (password) ->
	return (req, res, next) ->
		if req.query.password and req.query.password is password
			next()
		else
			res.send(401)
mongoUrlCreds = if process.env.MONGO_USERNAME then "#{process.env.MONGO_USERNAME}:#{process.env.MONGO_PASSWORD}@" else ""
mongoose.connect("mongodb://#{mongoUrlCreds}#{process.env.MONGO_HOST}/mre_test")



mongoose.model('Post', postSchema)
mongoose.model('Comment', commentSchema)
mongoose.model('Author', authorSchema)

mongoose.set 'debug', true



describe 'Fetch', ->

	describe 'Basic object', ->
		beforeEach (done) ->
			@endpoint = new mre('/api/posts', 'Post')
			@app = express()
			@app.use(bodyParser.urlencoded({extended: true}))
			@app.use(bodyParser.json())
			@app.use(methodOverride())

			modClass = mongoose.model('Post')
			mod = modClass
				date:Date.now()
				number:5
				string:'Test'
			mod.save (err, res) =>
				@mod = res
				done()
		afterEach (done) ->
			@mod.remove ->
				done()
		it 'should retrieve with no hooks', (done) ->
			

			@endpoint.register(@app)

			
			request(@app).get('/api/posts/' + @mod._id).end (err, res) ->
				console.log res.text
				res.status.should.equal(200)
				res.body.number.should.equal(5)
				res.body.string.should.equal('Test')
				done()

		it 'should honor bad pre_filter hook', (done) ->
			@endpoint.tap 'pre_filter', 'fetch', (args, data, next) ->
				data.number = 6
				next(data)
			.register(@app)

			request(@app).get('/api/posts/' + @mod._id).end (err, res) ->
				res.status.should.equal(404)
				done()

		it 'should honor good pre_filter hook', (done) ->
			@endpoint.tap 'pre_filter', 'fetch', (args, data, next) ->
				data.number = 5
				next(data)
			.register(@app)

			request(@app).get('/api/posts/' + @mod._id).end (err, res) ->
				res.status.should.equal(200)
				done()

		it 'should honor pre_response hook', (done) ->
			@endpoint.tap 'pre_response', 'fetch', (args, model, next) ->
				delete model.number
				next(model)
			.register(@app)
			request(@app).get('/api/posts/' + @mod._id).end (err, res) ->
				res.status.should.equal(200)
				should.not.exist(res.body.number)
				done()

		it 'should honor pre_response_error hook', (done) ->
			@endpoint.tap 'pre_response_error', 'fetch', (args, err, next) ->
				err.message = 'Foo'
				next(err)
			.register(@app)

			# ID must be acceptable otherwise we'll get a 400 instead of 404
			request(@app).get('/api/posts/abcdabcdabcdabcdabcdabcd').end (err, res) ->
				res.status.should.equal(404)
				res.text.should.equal('Foo')
				done()


		
	describe 'With middleware', ->
		beforeEach (done) ->
			@endpoint = new mre('/api/posts', 'Post')
			@app = express()
			@app.use(bodyParser.urlencoded({extended: true}))
			@app.use(bodyParser.json())
			@app.use(methodOverride())

			modClass = mongoose.model('Post')
			mod = modClass
				date:Date.now()
				number:5
				string:'Test'
			mod.save (err, res) =>
				@mod = res
				done()
		afterEach (done) ->
			@mod.remove ->
				done()
		it 'should retrieve with middleware', (done) ->
			
			@endpoint.addMiddleware('fetch', requirePassword('asdf'))
			@endpoint.register(@app)

			
			request(@app).get('/api/posts/' + @mod._id).query
				password:'asdf'
			.end (err, res) ->
				res.status.should.equal(200)
				res.body.number.should.equal(5)
				res.body.string.should.equal('Test')
				done()

		it 'should give a 401 with wrong password', (done) ->
			@endpoint.addMiddleware('fetch', requirePassword('asdf'))
			@endpoint.register(@app)

			
			request(@app).get('/api/posts/' + @mod._id).query
				password:'ffff'
			.end (err, res) ->
				res.status.should.equal(401)
				done()


	describe 'Populate', ->
		beforeEach (done) ->
			@endpoint = new mre('/api/posts', 'Post')
			@app = express()
			@app.use(bodyParser.urlencoded({extended: true}))
			@app.use(bodyParser.json())
			@app.use(methodOverride())

			modClass = mongoose.model('Post')
			mod = modClass
				date:Date.now()
				number:5
				string:'Test'
			comment = new (mongoose.model('Comment'))()
			comment._post = mod._id
			comment.comment = 'Asdf1234'
			comment.otherField = 5

			mod._comments = [comment._id]
			@mod = mod
			Q.all([mod.save(), comment.save()]).then ->
				done()
			.fail(done).done()
		afterEach (done) -> 
			@mod.remove ->
				done()
		it 'should populate', (done) ->

			@endpoint.populate('_comments').register(@app)


			request(@app).get('/api/posts/' + @mod._id).end (err, res) ->
				res.status.should.equal(200)
				res.body.number.should.equal(5)
				res.body.string.should.equal('Test')
				res.body._comments.length.should.equal(1)
				res.body._comments[0].comment.should.equal('Asdf1234')
				res.body._comments[0].otherField.should.equal(5)
				done()
		it 'should populate when specifying fields', (done) ->
			@endpoint.populate('_comments', 'comment').register(@app)

			request(@app).get('/api/posts/' + @mod._id).end (err, res) ->
				res.status.should.equal(200)
				res.body.number.should.equal(5)
				res.body.string.should.equal('Test')
				res.body._comments.length.should.equal(1)
				res.body._comments[0].comment.should.equal('Asdf1234')
				should.not.exist(res.body._comments[0].otherField)
				done()
