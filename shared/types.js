"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ValidationResult = exports.PetState = void 0;
var PetState;
(function (PetState) {
    PetState["EGG"] = "Egg";
    PetState["HATCHED"] = "Hatched";
})(PetState || (exports.PetState = PetState = {}));
var ValidationResult;
(function (ValidationResult) {
    ValidationResult["ACCEPTED"] = "accepted";
    ValidationResult["REJECTED"] = "rejected";
    ValidationResult["SUSPICIOUS"] = "suspicious";
})(ValidationResult || (exports.ValidationResult = ValidationResult = {}));
