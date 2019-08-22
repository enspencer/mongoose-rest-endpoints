express = require 'express'
bodyParser = require 'body-parser'
methodOverride = require 'method-override'
request = require 'supertest'
should = require 'should'
Q = require 'q'

mongoose = require 'mongoose'
require('../lib/log').verbose(true)
mre = require '../lib/endpoint'
# Custom "Post" and "Comment" documents
moment = require 'moment'
commentSchema = new mongoose.Schema
	comment:String
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
	_author:
		type:mongoose.Schema.Types.ObjectId
		ref:'Author'

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



describe 'Post', ->
	@timeout(5000)
	describe 'Basic object', ->
		beforeEach (done) ->
			@endpoint = new mre('/api/posts', mongoose.model('Post'))
			@app = express()
			@app.use(bodyParser.urlencoded({extended: true}))
			@app.use(bodyParser.json())
			@app.use(methodOverride())
			done()
		afterEach (done) ->
			# clear out
			mongoose.connection.collections.posts.drop()
			done()
		it 'should let you post with no hooks', (done) ->

			@endpoint.register(@app)

			data = 
				date:Date.now()
				number:5
				string:'Test'

			request(@app).post('/api/posts/').send(data).end (err, res) ->
				res.status.should.equal(201)
				res.body.number.should.equal(5)
				res.body.string.should.equal('Test')
				done()

		it 'should run middleware', (done) ->
			@endpoint.addMiddleware('post', requirePassword('asdf')).register(@app)
			data = 
				date:Date.now()
				number:5
				string:'Test'

			

			request(@app).post('/api/posts/').query
				password:'asdf'
			.send(data).end (err, res) =>
				res.status.should.equal(201)
				res.body.number.should.equal(5)
				res.body.string.should.equal('Test')

				request(@app).post('/api/posts/').query
					password:'ffff'
				.send(data).end (err, res) =>
					res.status.should.equal(401)
					done()


		it 'should run pre save', (done) ->
			postData = 
				date:Date.now()
				number:5
				string:'Test'

			@endpoint.tap 'pre_save', 'post', (req, model, next) ->
				model.set('number', 8)
				next(model)
			.register(@app)

			request(@app).post('/api/posts/').send(postData).end (err, res) ->
				res.status.should.equal(201)
				res.body.number.should.equal(8)
				res.body.string.should.equal('Test')
				done()

		it 'should handle a thrown error on pre save', (done) ->
			postData = 
				date:Date.now()
				number:5
				string:'Test'

			@endpoint.tap 'pre_save', 'post', (req, model, next) ->
				setTimeout ->
					err = new Error('test')
					err.code = 405
					next(err)
				, 2000
			.register(@app)

			request(@app).post('/api/posts/').send(postData).end (err, res) ->
				res.status.should.equal(405)
				done()

		it 'should run pre response', (done) ->
			postData = 
				date:Date.now()
				number:5
				string:'Test'

			@endpoint.tap 'pre_response', 'post', (req, data, next) ->
				setTimeout ->
					data.number = 7
					next(data)
				, 2000
				return null
			.register(@app)

			request(@app).post('/api/posts/').send(postData).end (err, res) ->
				res.status.should.equal(201)
				res.body.number.should.equal(7)
				res.body.string.should.equal('Test')

				# Make sure it didn't actually update the post
				mongoose.model('Post').findById res.body._id, (err, mod) ->
					mod.number.should.equal(5)
					done()

	