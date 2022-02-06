/* Copyright (c) 2020 by InterSystems Corporation.
   Cambridge, Massachusetts, U.S.A.  All rights reserved.
   Confidential property of InterSystems Corporation. */

/// %REST.Parameter checks and does code generation for parameters.
/// %REST.Parameter also maintains the index of all parameters by route.
/// 
/// This class is used internally by InterSystems IRIS. You should not make direct
/// use of it within your applications. There is no guarantee made about either
/// the behavior or future operation of this class.
Class %REST.Parameter Extends %RegisteredObject [ Hidden, System = 3 ]
{

/// The index of all parameters for a route or map.
/// The format is parameterIndex(<route/map>,<in>,<name>)=<parameter> and
/// parameterIndex(<route/map>,<in>,<name>,0)=<isLocal><br/>
Property parameterIndex As %REST.RESTSpec.ParameterObject [ Internal, MultiDimensional ];

/// Create an index of the parameters associated with the specified route.
/// Also validity check the parameters.<br/>
Method CreateParameterIndex(generator As %REST.Generator, route As %REST.RESTSpec.RouteItemObject, id As %String) As %Status [ Internal ]
{
	// Resolve parameter references
	Set sc=..ResolveParameterReferences(generator,route,id)
	If $$$ISERR(sc) Quit sc
	
	Set bodyFound=0
	Set formDataFound=0

	Set parameters=route.parameters	
	// For each route loop over parameters
	For idx=1:1:parameters.Count() {
		Set parameter=parameters.GetAt(idx)
		// Each parameter must have name specified
		Set name=parameter.name
		If name="" {
			Set sc=$$$ERROR($$$RESTSpecMissing,"name","operation("_id_").parameters("_idx_")",generator.specClassName)
			Quit
		}

		// Each parameter must have valid in specified
		Set in=parameter.in
		If in="" {
			Set sc=$$$ERROR($$$RESTSpecMissing,"in","operation("_id_").parameters("_idx_")",generator.specClassName)
			Quit
		}
		If $case(in,"path":0,"header":0,"query":0,"formData":0,"body":0,:1) {
			Set sc=$$$ERROR($$$RESTInvalidProperty,"in",in)
			Quit
		}
		If in="body" {
			If bodyFound {
				Set sc=$$$ERROR($$$RESTBody2,"operation("_id_").parameters("_idx_")",generator.specClassName)
				Quit
			}
			Set bodyFound=1
		} ElseIf in="formData" {
			Set formDataFound=1
		}

		// Each parameter must have valid type specified
		Set type=parameter.type
		If in'="body" {
			If type="" {
				Set sc=$$$ERROR($$$RESTSpecMissing,"type","operation("_id_").parameters("_idx_")",generator.specClassName)
				Quit
			} ElseIf $case(type,"string":0,"number":0,"integer":0,"boolean":0,"array":0,"file":0,"object":0,:1) ||
			   ((type="file")&&(in'="formData")) || (type="object") {
				Set sc=$$$ERROR($$$RESTBadType,name,"operation("_id_").parameters("_idx_")",generator.specClassName)
				Quit
			}
		}

		// If array type, then items must be simple type, not array or object.		
		If type="array",$case(parameter.items.type,"array":1,"object":1,:0) {
			Set sc=$$$ERROR($$$RESTBadItemsType,parameter.name,"operation("_id_").parameters("_idx_")",generator.specClassName)
		}
		
		// Two parameters may not have same in and name
		If $data(index(in,name)) {
			Set sc=$$$ERROR($$$RESTDuplicateParam,name,"operation("_id_").parameters("_idx_")",generator.specClassName)
			Quit
		}
		
		// Add property for the parameter name and location.
		Set index(in,name)=parameter
		Set index(in,name,0)=1
	}
	
	// Cannot have both body and formData parameter in the list
	If $$$ISOK(sc),bodyFound,formDataFound {
		Set sc=$$$ERROR($$$RESTBodyAndForm,"operation("_id_").parameters("_idx_")",generator.specClassName)
	}
	
	// Save index if success 
	If $$$ISOK(sc) Merge ..parameterIndex(route)=index
	
	Quit sc
}

/// Find the parameter based on the index
Method GetParameter(route As %REST.RESTSpec.RouteItemObject, in As %String, name As %String) As %REST.Parameter
{
	Quit $get(..parameterIndex(route,in,name))
}

/// Get a list of all parameter names of the specified type.
Method GetParametersIn(route As %REST.RESTSpec.RouteItemObject, in As %String, isLocal As %Boolean = "") As %List [ Internal ]
{
	Set namelist=""
	Set name=""
	For {
		Set name=$order(..parameterIndex(route,in,name))
		If name="" Quit
		If (isLocal="") || (isLocal=..parameterIndex(route,in,name,0)) {
			Set namelist=namelist_$lb(name)
		}
	}
	Quit namelist
}

/// If parameter is a reference, then replace it with the referenced parameter.
/// Reference are [<className>:[<xdataName>.]]<referenceName> where reference name is in parameters section.
Method ResolveParameterReferences(generator As %REST.Generator, route As %REST.RESTSpec.RouteItemObject, id As %String) As %Status [ Internal ]
{
	Set sc=$$$OK

	Set spec=generator.spec
	
	// For each route loop over parameters
	Set parameters=route.parameters
	For idx=1:1:parameters.Count() {
		Set parameter=parameters.GetAt(idx)

		// If reference specifed then replace the parameter with the referenced parameter.
		Set reference=parameter.reference
		If reference'="" {
			// If reference specified then no other field allowed.
			If parameter.name'="" {
				Set sc=$$$ERROR($$$RESTInvalidRef,"operation("_id_").parameters("_idx_")",generator.specClassName)
				Quit
			}
			
			// Validate the format of the reference as <className>:<xdataName>.<referenceName>
			// and find the referenced parameter
			Set sc=spec.GetReference("parameters",generator.specClassName,spec,reference,.refparm)
			If $$$ISERR(sc) Quit
			
			// Replace the parameter with the referenced parameter, keeping the original name.
			Do parameters.SetAt(refparm,idx)
		}
		
		// If schema for the parameter is a reference, then replace with the schema.
		Set schema=parameter.schema
		If $isobject(schema),schema.reference'="" {
			// If reference specified then no other field allowed.
			If parameter.type'="" {
				Set sc=$$$ERROR($$$RESTInvalidRef,"operation("_id_").schemas("_idx_")",generator.specClassName)
				Quit
			}
			
			// Validate the format of the reference as <className>:<xdataName>.<referenceName>
			// and find the referenced schema
			Set sc=spec.GetReference("schemas",generator.specClassName,spec,schema.reference,.refschema)
			If $$$ISERR(sc) Quit
			
			// Replace the schema with the referenced schema.
			Set parameter.schema=refschema
		}
	}
	
	Quit sc
}

/// Generate code to get and validate a parameter value.
ClassMethod ParameterCodeGen(parameter As %REST.RESTSpec.ParameterObject, consumes As %String, indent As %String) As %Status [ Internal ]
{
	Set in=parameter.in
	Set name=parameter.name
	
	// Normalize argument name to 1 shorter than allowed in order to be able to prefix with p.
	Set argName="p"_##class(%REST.Generator).NormalizeName(name)

	// Text to be used too assign single values.  %valText will be substituted.
	Set assignText="Set "_argName_"=%valText"

	If in="path" {
		Set sc=..ParameterCodePath(parameter,assignText,argName,indent)

	} ElseIf in="header" {
		Set sc=..ParameterCodeHeader(parameter,assignText,argName,indent)

	} ElseIf in = "query" {
		Set sc=..ParameterCodeQuery(parameter,assignText,argName,indent)

	} ElseIf in="formData" {
		Set sc=..ParameterCodeQuery(parameter,assignText,argName,indent)

	} ElseIf in="body" {
		Set sc=..ParameterCodeBody(parameter,consumes,argName,indent)

	} Else {
		Set sc=$$$ERROR($$$RESTBadIn,name,"","")
	}
	
	Quit sc
}

/// Generate code to get and validate a parameter value located in the path.
ClassMethod ParameterCodePath(parameter As %REST.RESTSpec.ParameterObject, assignText As %String, argName As %String, indent As %String) As %Status [ Internal ]
{
	Set sc=..SimpleValueCode(parameter,assignText,argName,indent)
	Quit sc
}

/// Generate code to get and validate a parameter value located in a header.
ClassMethod ParameterCodeHeader(parameter As %REST.RESTSpec.ParameterObject, assignText As %String, argName As %String, indent As %String) As %Status [ Internal ]
{
	Set name=parameter.name
	Set uName = "HTTP_"_$translate($zcvt(name,"U"),"-","_")
	If parameter.required {
		Set localIndent=indent
		Set needClosingBrace=0
		$$$GENERATE(indent_"If '$data(%request.CgiEnvs("""_uName_""")) Do ##class(%REST.Impl).%ReportRESTError(..#HTTP400BADREQUEST,$$$ERROR($$$RESTRequired,"""_name_""")) Quit")
		$$$GENERATE(indent_"Set "_argName_"=%request.CgiEnvs("""_uName_""")")
	} Else {
		Set localIndent=indent_"    "
		Set needClosingBrace=1
		$$$GENERATE(indent_"If $data(%request.CgiEnvs("""_uName_""")) {")
		$$$GENERATE(localIndent_"Set "_argName_"=%request.CgiEnvs("""_uName_""")")
	}
	Set sc=..SimpleValueCode(parameter,assignText,argName,localIndent)
	If needClosingBrace {
		$$$GENERATE(indent_"}")
	}
	Quit sc
}

/// Generate code to get and validate a parameter value located in a query parameter.
ClassMethod ParameterCodeQuery(parameter As %REST.RESTSpec.ParameterObject, assignText As %String, argName As %String, indent As %String) As %Status [ Internal ]
{
	Set name=parameter.name
	
	If parameter.type="file" {
		Set requestProperty = "MimeData"
	} Else {
		Set requestProperty = "Data"
	}
	If parameter.required {
		$$$GENERATE(indent_"If '$data(%request."_requestProperty_"("""_name_""",1)) Do ##class(%REST.Impl).%ReportRESTError(..#HTTP400BADREQUEST,$$$ERROR($$$RESTRequired,"""_name_""")) Quit")
	}

	If parameter.type="array",parameter.collectionFormat="multi" {
		// Get values from %request.Data later.
		Set sc=..SimpleValueCode(parameter,assignText,argName,indent)
		
	} Else {
		$$$GENERATE(indent_"If $data(%request."_requestProperty_"("""_name_""",2)) {")
		$$$GENERATE(indent_"    Do ##class(%REST.Impl).%ReportRESTError(..#HTTP400BADREQUEST,$$$ERROR($$$RESTDuplicate,"""_name_""")) Quit")
		$$$GENERATE(indent_"}")
		Set needClosingBrace=0
		If parameter.type="array",parameter.minItems=0 {
			Set needClosingBrace=1
			Set localIndent=indent_"    "
			$$$GENERATE(indent_"Set "_argName_"=$get(%request."_requestProperty_"("""_name_""",1))")
			$$$GENERATE(indent_"If "_argName_"'="""" {")
		} 
		ElseIf parameter.type="array",parameter.minItems="" {
			Set needClosingBrace=1
			Set localIndent=indent_"    "
			$$$GENERATE(indent_"Set "_argName_"=$get(%request."_requestProperty_"("""_name_""",1))")
			$$$GENERATE(indent_"If "_argName_"'="""" {")
		} 
		ElseIf 'parameter.required {
			Set needClosingBrace=1
			Set localIndent=indent_"    "
			$$$GENERATE(indent_"If $data(%request."_requestProperty_"("""_name_""",1)) {")
			$$$GENERATE(localIndent_"Set "_argName_"=%request."_requestProperty_"("""_name_""",1)")
		} Else {
			Set localIndent=indent
			$$$GENERATE(localIndent_"Set "_argName_"=%request."_requestProperty_"("""_name_""",1)")
		}
		Set sc=..SimpleValueCode(parameter,assignText,argName,localIndent)
		If needClosingBrace {
			$$$GENERATE(indent_"}")
		}
	}


	Quit sc
}

/// Generate code to get and validate a parameter value located in the request body.
ClassMethod ParameterCodeBody(parameter As %REST.RESTSpec.ParameterObject, consumes As %String, argName As %String, indent As %String) As %Status [ Internal ]
{
	Set name=parameter.name
	If consumes="application/json",$isobject(parameter.schema),parameter.schema.type="object" {
		If parameter.required {
			$$$GENERATE(indent_"If '$isobject(%request.Content) || (%request.Content.Size=0) Do ##class(%REST.Impl).%ReportRESTError(..#HTTP400BADREQUEST,$$$ERROR($$$RESTRequired,"""_name_""")) Quit")
			$$$GENERATE(indent_"Set "_argName_"=##class(%DynamicAbstractObject).%FromJSON(%request.Content)")
		} Else {
			$$$GENERATE(indent_"If $isobject(%request.Content),%request.Content.Size>0 Set "_argName_"=##class(%DynamicAbstractObject).%FromJSON(%request.Content)")
		}
	} 
	ElseIf consumes="application/json",$isobject(parameter.schema),parameter.schema.type="array" {
		If parameter.required {
			$$$GENERATE(indent_"If '$isobject(%request.Content) || (%request.Content.Size=0) Do ##class(%REST.Impl).%ReportRESTError(..#HTTP400BADREQUEST,$$$ERROR($$$RESTRequired,"""_name_""")) Quit")
			$$$GENERATE(indent_"Set "_argName_"=##class(%DynamicArray).%FromJSON(%request.Content)")
		} Else {
			$$$GENERATE(indent_"If $isobject(%request.Content),%request.Content.Size>0 Set "_argName_"=##class(%DynamicArray).%FromJSON(%request.Content)")
		}
	}
	Else {
		If parameter.required {
			$$$GENERATE(indent_"If '$isobject(%request.Content) Do ##class(%REST.Impl).%ReportRESTError(..#HTTP400BADREQUEST,$$$ERROR($$$RESTRequired,"""_name_""")) Quit")
			$$$GENERATE(indent_"Set "_argName_"=%request.Content")
		} Else {
			$$$GENERATE(indent_"If $isobject(%request.Content) Set "_argName_"=%request.Content")
		}
	}
	
	Quit $$$OK
}

/// Generate and return as a string the code needed to validate a simple input value.
/// If the returned code is "", then an error was detected while generating the code.
/// In the case of invalid input, the generated code will call %ReportRESTError.
ClassMethod SimpleValueCode(parameter As %REST.RESTSpec.ParameterObject, assignText As %String, valName As %String, indent As %String, name As %String = "") As %Status [ Internal ]
{
	Set sc=$$$OK
	// name argument only passed for arrays
	If $get(name)="" Set name=parameter.name
	Set type=parameter.type
	
	If type="string" {
		Set sc=..SimpleStringCode(parameter,valName,indent,.valText,.testText)
		
	} ElseIf type="number" {
		Set sc=..SimpleNumberCode(parameter,valName,indent,.valText,.testText)

	} ElseIf type="integer" {
		Set sc=..SimpleIntegerCode(parameter,valName,indent,.valText,.testText)

	} ElseIf type="boolean" {
		Set sc=..SimpleBooleanCode(parameter,valName,indent,.valText,.testText)

	} ElseIf type="array" {
		Set sc=..SimpleArrayCode(parameter,valName,indent,.valText,.testText)

	} ElseIf type="file" {
		Set sc=..SimpleFileCode(parameter,valName,indent,.valText,.testText)

	} Else {
		Set sc=$$$ERROR($$$RESTBadType,name,"","")
	}

	If $$$ISOK(sc) {
		If testText'="" {
			$$$GENERATE(indent_"If "_testText_" Do ##class(%REST.Impl).%ReportRESTError(..#HTTP400BADREQUEST,$$$ERROR($$$RESTInvalid,"""_name_""","_valName_")) Quit")
		}
		// valText begins with "p" only if parameter name.  In this case replace is not needed.
		If $extract(valText)'="p" {
			$$$GENERATE(indent_$replace(assignText,"%valText",valText))
		}
	}
	
	Quit sc
}

/// Generate code to validate string value.
ClassMethod SimpleStringCode(parameter As %REST.RESTSpec.ParameterObject, valName As %String, indent As %String, Output valText As %String, Output testText As %String) As %Status [ Internal ]
{
	Set format=parameter.format
	
	Set valText=valName
	Set testText=""

	Set delim=""
	If format="byte" {
		$$$GENERATE(indent_"Set "_valName_"=$system.Encryption.Base64Decode("_valName_")")
	} ElseIf format="date" {
		Set testText="(##class(%Date).XSDToLogical("_valName_")="""")"
		Set delim="||"
	} ElseIf format="date-time" {
		Set testText="(##class(%TimeStamp).XSDToLogical("_valName_")="""")"
		Set delim="||"
	}
	Set maxLength=parameter.maxLength
	Set minLength=parameter.minLength
	Set pattern=parameter.pattern
	If maxLength'="" {
		Set testText=testText_delim_"($length("_valText_")>"_maxLength_")"
		Set delim="||"
	}
	If minLength'="" {
		Set testText=testText_delim_"($length("_valText_")<"_minLength_")"
		Set delim="||"
	}
	If pattern'="" {
		Set testText=testText_delim_"'$match("_valText_","""_pattern_""")"
	}
	
	Quit $$$OK
}

/// Generate code to validate number value.
ClassMethod SimpleNumberCode(parameter As %REST.RESTSpec.ParameterObject, valName As %String, indent As %String, Output valText As %String, Output testText As %String) As %Status [ Internal ]
{
	Set format=parameter.format
	
	Set valText=valName
	Set testText=""

	Set maximum=parameter.maximum
	Set exclusiveMaximum=parameter.exclusiveMaximum
	Set minimum=parameter.minimum
	Set exclusiveMinimum=parameter.exclusiveMinimum
	Set multipleOf=parameter.multipleOf
	Set testText="'$isvalidnum("_valName
	If (minimum'="")||(maximum'="") Set testText=testText_",,"_minimum
	If maximum'="" Set testText=testText_","_maximum
	Set testText=testText_")"

	If maximum'="",exclusiveMaximum {
		Set maximum=+maximum
		Set testText=testText_"||(+"_valName_">="_maximum_")"
	}
	If minimum'="",exclusiveMinimum {
		Set minimum=+minimum
		Set testText=testText_"||(+"_valName_"<="_minimum_")"
	}
	If multipleOf'="" {
		Set testText=testText_"||(("_valName_"#"_multipleOf_")'=0)"
	}
	
	Quit $$$OK
}

/// Generate code to validate integer value.
ClassMethod SimpleIntegerCode(parameter As %REST.RESTSpec.ParameterObject, valName As %String, indent As %String, Output valText As %String, Output testText As %String) As %Status [ Internal ]
{
	Set format=parameter.format
	
	Set valText=valName
	Set testText=""

	Set maximum=parameter.maximum
	Set minimum=parameter.minimum
	Set multipleOf=parameter.multipleOf
	If format="int32" {
		If minimum="" Set minimum=-2147483648
		If maximum="" Set maximum=2147483647
	} ElseIf format="int64" {
		If minimum="" Set minimum=-9223372036854775808
		If maximum="" Set maximum=9223372036854775807
	}
	If maximum'="",parameter.exclusiveMaximum Set maximum=maximum-1
	If minimum'="",parameter.exclusiveMinimum Set minimum=minimum+1
	Set testText="($number("_valName_",""I"""
	If (minimum'="")||(maximum'="") Set testText=testText_","_minimum
	If maximum'="" Set testText=testText_","_maximum
	Set testText=testText_")="""")"
	If multipleOf'="" {
		Set testText=testText_"||(("_valName_"#"_multipleOf_")'=0)"
	}
	
	Quit $$$OK
}

/// Generate code to validate boolean value.
ClassMethod SimpleBooleanCode(parameter As %REST.RESTSpec.ParameterObject, valName As %String, indent As %String, Output valText As %String, Output testText As %String) As %Status [ Internal ]
{
	Set format=parameter.format
	
	$$$GENERATE(indent_"Set "_valName_"=$case("_valName_",1:1,0:0,""true"":1,""false"":0,:-1)")
	Set testText=valName_"<0"
	Set valText=valName
	
	Quit $$$OK
}

/// Generate code to validate file value.
ClassMethod SimpleFileCode(parameter As %REST.RESTSpec.ParameterObject, valName As %String, indent As %String, Output valText As %String, Output testText As %String) As %Status [ Internal ]
{
	Set format=parameter.format
	
	$$$GENERATE(indent_"Set stream=##class(%GlobalCharacterStream).%New()")
	$$$GENERATE(indent_"If $isobject("_valName_") {")
	$$$GENERATE(indent_"    Do "_valName_".Rewind()")
	$$$GENERATE(indent_"    Set sc=stream.CopyFrom("_valName_")")
	$$$GENERATE(indent_"} Else {")
	$$$GENERATE(indent_"    Set sc=stream.Write("_valName_")")
	$$$GENERATE(indent_"}")
	Set testText="$$$ISERR(sc)"
	Set valText="stream"
	
	Quit $$$OK
}

/// Generate code to validate array value.
ClassMethod SimpleArrayCode(parameter As %REST.RESTSpec.ParameterObject, valName As %String, indent As %String, Output valText As %String, Output testText As %String) As %Status [ Internal ]
{
	Set testText=""
	Set delim=""

	// The array items may not be of type object or array.
	Set name=parameter.name
	Set itemsType=parameter.items.type
	If $case(itemsType,"array":1,"object":1,:0) {
		Quit $$$ERROR($$$RESTBadItemsType,name,"","")
	}
	
	Set collectionFormat=parameter.collectionFormat
	Set sep=$case(collectionFormat,"":""",""","csv":""",""","ssv":""" ""","tsv":"$char(9)","pipes":"""|""",:"")

	Set valText=valName
	If sep '="" {
		// Text to be used to assign value in an array.  %valText will be substituted.
		Set assignText="Do array.Insert(%valText)"
	
		$$$GENERATE(indent_"Set array=##class(%ListOfDataTypes).%New()")
		$$$GENERATE(indent_"For index=1:1:$length("_valName_","_sep_") {")
		$$$GENERATE(indent_"    Set arrayVal=$piece("_valName_","_sep_",index)")
		Set sc=..SimpleValueCode(parameter.items,assignText,"arrayVal",indent_"    ",name_"()")
		$$$GENERATE(indent_"}")
		$$$GENERATE(indent_"Set "_valName_"=array")

	} ElseIf collectionFormat="multi" {
		// Text to be used to assign value in an array.  %valText will be substituted.
		Set assignText="Do "_valName_".Insert(%valText)"
	
		$$$GENERATE(indent_"Set "_valName_"=##class(%ListOfDataTypes).%New(),index=""""")
		$$$GENERATE(indent_"For {")
		$$$GENERATE(indent_"    Set index=$order(%request.Data("""_name_""",index),1,arrayVal)")
		$$$GENERATE(indent_"    If index="""" Quit")
		Set sc=..SimpleValueCode(parameter.items,assignText,"arrayVal",indent_"    ",name_"()")
		$$$GENERATE(indent_"}")

	} Else {
		Set sc=$$$ERROR($$$RESTInvalidProperty,"collectionFormat",collectionFormat)

	}
	
	If $$$ISOK(sc) {
		Set minItems=parameter.minItems
		Set maxItems=parameter.maxItems

		If (minItems'="") || (maxItems'="") {
			$$$GENERATE(indent_"Set size="_valName_".Size")
		}

		If minItems'="" {
			Set testText=testText_delim_"(size<"_minItems_")"
			Set delim="||"
		}

		If maxItems'="" {
			Set testText=testText_delim_"(size>"_maxItems_")"
			Set delim="||"
		}

		If parameter.uniqueItems {
			Set testText=testText_delim_"'##class(%REST.Impl).%CheckUniqueArray(array)"
		}
	}

	Quit sc
}

/// Get the ObjectScript type for a parameter.
ClassMethod GetObjectScriptType(parameter As %REST.RESTSpec.ParameterObject) As %String [ Internal ]
{
#define SimpleType(%type) $case(%type,"string":"%String","number":"%Float","integer":"%Integer","boolean":"%Boolean",:"%String")
	Set type=parameter.type
	Set assignType=type
	
	If type="array" {
		Set itemsType=parameter.items.type
		Set objectScriptType="%ListOfDataTypes(ELEMENTTYPE="""_$$$SimpleType(parameter.items.type)_""")"
		
	} ElseIf type="file" {
		Set objectScriptType="%Stream.Object"

	} Else {
		Set objectScriptType=$$$SimpleType(type)
	}
	
	Quit objectScriptType
}

}
