//
// Created by Devin on 3/29/2018.
//

#include <gdnative_api_struct.gen.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

//Import the API
const godot_gdnative_core_api_struct *api = NULL;
const godot_gdnative_ext_nativescript_api_struct *nativescript_api = NULL;

//Build simple constructor and destructor
void *simple_constructor(godot_object *p_instance, void *p_method_data);
void *simple_deconstructor(godot_object *p_instance, void *p_method_data, void *p_user_data);

//Simple get_data function
godot_variant simple_get_data(godot_object *p_instance, void *p_method_data, void *p_user_data, int num_args, godot_variant **p_args);

//Function for initializing gdnative
void GDN_EXPORT godot_gdnative_init(godot_gdnative_init_options *p_options){
    //Get the api from the options
    api = p_options->api_struct;

    //Go through all the extensions
    for(int i = 0; i < api->num_extensions; ++i){
        //What kind of extension did we get?
        switch (api->extensions[i]->type){
            case GDNATIVE_EXT_NATIVESCRIPT: {
                //Get the nativescript API from this extension
                nativescript_api = (godot_gdnative_ext_nativescript_api_struct *)api->extensions[i];
            };
                break;
            default:
                break;
        }
    }
}

//Cleanup function for when this is no longer used
void GDN_EXPORT godot_gdnative_terminate(godot_gdnative_terminate_options *p_options){
    //Just kill the API's
    api = NULL;
    nativescript_api = NULL;
}

//Add the initialization function
void GDN_EXPORT godot_nativescript_init(void *p_handle){
    //Create an empty create function
    godot_instance_create_func create = { NULL, NULL, NULL };
    create.create_func = &simple_constructor;

    //Also create a destroy function
    godot_instance_destroy_func destroy = { NULL, NULL, NULL };
    destroy.destroy_func = &simple_deconstructor;

    //Register this class with the given functions
    nativescript_api->godot_nativescript_register_class(p_handle, "SIMPLE", "Reference", create, destroy);

    //Now register our simple function (get_data)
    godot_instance_method get_data = { NULL, NULL, NULL };
    get_data.method = &simple_get_data;

    //Disable RPC mode (not sure what this does)
    godot_method_attributes attributes = { GODOT_METHOD_RPC_MODE_DISABLED };

    //Now actually expose the get_data method
    nativescript_api->godot_nativescript_register_method(p_handle, "SIMPLE", "get_data", attributes, get_data);
}

//Define a struct to hold our user data
typedef struct user_data_struct {
    //Simply a bunch of characters
    char data[256];
} user_data_struct;

//Actually define the constructor
void *simple_constructor(godot_object *p_instance, void *p_method_data) {
    //Make some user data
    user_data_struct *user_data = api->godot_alloc(sizeof(user_data_struct));

    //Just copy a string
    strcpy(user_data->data, "Hello World from GDNative!");

    //Return our generated data
    return user_data;
}

//Make a simple deconstructor
void *simple_deconstructor(godot_object *p_instance, void *p_method_data, void *p_user_data){
    //Kill it
    api->godot_free(p_user_data);
}

//Finally let's make our simple function
godot_variant simple_get_data(godot_object *p_instance, void *p_method_data, void *p_user_data, int p_num_args, godot_variant **p_args){
    //Initialize the string data and the return value
    godot_string data;
    godot_variant ret;

    //Get the data from the user struct
    user_data_struct *user_data = (user_data_struct *) p_user_data;

    //Make the string
    api->godot_string_new(&data);

    //Parse the string from the user data and put it into data
    api->godot_string_parse_utf8(&data, user_data->data);

    //Make a new string and put it into ret as a variant string
    api->godot_variant_new_string(&ret, &data);

    //Finally kill the old string
    api->godot_string_destroy(&data);

    //Return the data
    return ret;
}