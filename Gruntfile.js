
var f, semver;

semver = require('semver');
var f = require('util').format;
var fs = require('fs');

module.exports = function(grunt) {
	grunt.loadNpmTasks('grunt-contrib-watch');
	grunt.loadNpmTasks('grunt-exec');
	grunt.loadNpmTasks('grunt-contrib-coffee');
	grunt.initConfig({
		version: grunt.file.readJSON('package.json').version,
		watch: {
			coffee:{
				files:['coffee/**/*.coffee', 'coffee/*.coffee'],
				tasks:['coffee']
			}
		},
		exec:{
			test: {
				cmd:function(ex) {
					return f('NODE_ENV=test mocha --exit --require coffee-script/register %s', ex)
				}
			}
		}
	});

	grunt.registerTask('dropTestDb', function() {
		var mongoose = require('mongoose');
		var done = this.async();
		var mongoUrlCreds = process.env.MONGO_USERNAME 
			? (process.env.MONGO_USERNAME+":"+process.env.MONGO_PASSWORD+"@") 
			: "";
		var mongoUrl = "mongodb://" + mongoUrlCreds + process.env.MONGO_HOST;
		mongoose.connect(mongoUrl+"/mre_test")
		mongoose.connection.on('open', function () { 
			mongoose.connection.db.dropDatabase(function(err) {
				if(err) {
					console.log(err);
				} else {
					console.log('Successfully dropped db');
				}
				mongoose.connection.close(done);
			});
		});
	});

	grunt.registerTask('test', 'Run tests', function(type) {
		var tasks = ['dropTestDb'];
		if(type === undefined) {
			type = 'all';
		}
		switch(type) {

			case 'all':
				var files = fs.readdirSync('test');
				var file;
				for(var i=0;i<files.length;i++) {
					file = files[i];
					tasks.push('exec:test:"test/' + file + '"')
				}
				//tasks = ['exec:test:"test/unit/*.js"']
				break;
			default:
				tasks = ['dropTestDb', 'exec:test:"test/' + type + '.coffee"', 'dropTestDb']
				break;
		}

		console.log(tasks);

		grunt.task.run(tasks);
	});
};
