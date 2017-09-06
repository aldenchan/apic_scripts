@Grab(group='io.swagger', module='swagger-core', version='1.5.10')
@Grab(group='io.swagger', module='swagger-parser', version='1.0.22')
@Grab(group='org.slf4j', module='slf4j-log4j12', version='1.7.21')
@Grab('log4j:log4j:1.2.17')
@Grab(group='commons-lang', module='commons-lang', version='2.6')

import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.Files;
import io.swagger.parser.SwaggerParser;
import io.swagger.models.*;
import io.swagger.util.Yaml;
import org.apache.log4j.Logger;
import org.apache.commons.io.FileUtils;
import groovy.util.CliBuilder; 
import groovy.util.FileNameFinder;
import org.apache.commons.lang.StringEscapeUtils;

FILESIZE=300000

def boolean cleanSwagger(String swaggerFilename, int filesize, boolean removeDescriptions, boolean removeExamples) {
	
	// init basic log4j
	org.apache.log4j.BasicConfigurator.configure();
	Logger logger = Logger.getLogger(CleanSwagger.class);
	
	try {
		Swagger swagger = new SwaggerParser().read(swaggerFilename);
		if (swagger == null) {
			System.err << "error parsing swagger file";
			return false;
		}
		
		
		File swaggerFile = new File(swaggerFilename);
		if (swaggerFile.length() < filesize ) {	// modify only if file is bigger than 300K
			logger.debug("file " + swaggerFilename + " is smaller than " + filesize + " bytes ");
			println("swagger file not modified: "+ swaggerFilename + " is smaller than " + filesize + " bytes ")
			return true;
		} else {
		
			Map<String, Model> definitions = swagger.getDefinitions();
			for (node in definitions) {
				Model model = node.getValue();
				String example = model.getExample();
								
				if (example != null) {
					if (removeExamples)
						node.getValue().setExample(null); // delete example
					// TODO: more complex example removable logic - maybe to keep the path examples
				}
				
				// Also delete the description
				String description = model.getDescription();
				if (description != null) {
					if (removeDescriptions)
						node.getValue().setDescription(null); // delete example
					// TODO: more complex example removable logic - maybe to keep the path examples
				}
								
			}
			// backup original yaml and then overwrite it
			String swaggerbackupfilename = swaggerFilename + ".cleanswagger.bak";
			File file = new File(swaggerbackupfilename);
			if (file.exists()) {
				int i = 1;
				while (new File(swaggerFilename + ".cleanswagger.bak" + "(" + i + ")" ).exists()) {
					i++
				}
				swaggerbackupfilename = swaggerFilename + ".cleanswagger.bak" + "(" + i + ")" ;
			}
			
			Files.move(Paths.get(swaggerFilename), Paths.get(swaggerbackupfilename));
			String swaggerString = Yaml.mapper().writeValueAsString(swagger);
			FileUtils.writeStringToFile(new File(swaggerFilename), swaggerString);
			println("swagger cleaned: " + swaggerFilename)

			return true;
		}
	} catch (Exception ex) {
		logger.error("error: " + ex.getMessage());
		ex.printStackTrace();
		return false;
	}
}

def boolean cleanSwaggerSwaggerDir(String dir, int filesize, boolean removeDescriptions, boolean removeExamples) {

	boolean cleanAllSuccess = true;
	cleanSuccessList = [];
	cleanFailedList = [];
		
	String[] swaggerFileList = new FileNameFinder().getFileNames(
		dir, '**/*.yaml' /* includes */, '**/*-product.yaml' /* excludes */)
	
	swaggerFileList.each {
		if (cleanSwagger(it, filesize, removeDescriptions, removeExamples)) {
			cleanSuccessList << it;
		} else {
			cleanAllSuccess = false;
			cleanFailedList << it;
		}		
	}
	
	println("the following files were modified: ");
	cleanSuccessList.each {
		println(it);
	}
	println("failed to modify the following files:")
	cleanFailedList.each {
		println(it);
	}
	 
	return cleanAllSuccess;
}


//TEST CASE
//cleanSwagger("inputs/accountarrangementservice.yaml",10)
//cleanSwaggerSwaggerDir("inputs", 10, true, true)
//System.exit(0);
//TEST CASE

def cli = new CliBuilder(usage: 'groovy CleanSwagger.groovy [[-d file] | [-d dir]] [-s filesize] [-ex] [-desc]| [-h]')
cli.h(longOpt:'help', 'help')
cli.f(longOpt:'file', args:1, argName:'file', 'swagger file to modify')
cli.d(longOpt:'dir', args:1, argName:'directory', 'modify all swagger files under the specified directory')
cli.s(longOpt:'size', args:1, argName:'filesize', 'modify swagger file(s) only if the file size is bigger than specified file size in bytes, default 300000 bytes')
cli.ex(longOpt:'examples', 'remove examples')
cli.desc(longOpt:'descriptions', 'remove descriptions')
def options = cli.parse(args)

int filesize = FILESIZE;
boolean removeDescriptions = false;
boolean removeExamples = false;

if (options.ex) removeExamples = true;
if (options.desc) removeDescriptions = true;
if (!removeExamples && !removeDescriptions) {
	cli.usage();
	System.exit(1);
}

if ((options.f) && (options.d)) {
	cli.usage();
	System.exit(1);
} 

if (options.s) {
	filesize = Integer.parseInt(options.s);
}

if (options.f) {
	File file = new File(options.f);
	if (!file.exists() || !file.isFile()) {
		System.err << "file not found: " + options.f
		System.exit(1);
	} else {
		// TODO: remove swagger examples
		if (cleanSwagger(options.f, filesize, removeDescriptions, removeExamples)) {
			System.exit(0);
		} else {
			System.exit(1);
		}
		
	}
}

if (options.d) {
	File file = new File(options.d);
	if (!file.exists() || !file.isDirectory()) {
		System.err << "directory not found: " + options.d
		System.exit(1);
	} else {
		// TODO: remove swagger examples from directory
		if (cleanSwaggerSwaggerDir(options.d, filesize, removeDescriptions, removeExamples)) {
			System.exit(0);
		} else {
			System.exit(1);
		}
	}
}

cli.usage();

