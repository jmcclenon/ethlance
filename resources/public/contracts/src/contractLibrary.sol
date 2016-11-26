pragma solidity ^0.4.4;

import "ethlanceDB.sol";
import "userLibrary.sol";
import "jobLibrary.sol";
import "sharedLibrary.sol";
import "jobActionLibrary.sol";

library ContractLibrary {

    //    status:
    //    1: running, 2: done

    function addContract(
        address db,
        uint senderId,
        uint jobActionId,
        uint rate,
        bool isHiringDone
    )
        internal
    {
        var jobId = JobActionLibrary.getJob(db, jobActionId);
        var freelancerId = JobActionLibrary.getFreelancer(db, jobActionId);
        var employerId = JobLibrary.getEmployer(db, jobId);
        if (senderId != employerId) throw;
        if (senderId == freelancerId) throw;
        var idx = SharedLibrary.createNext(db, "contract/count");
        EthlanceDB(db).setUIntValue(sha3("contract/job", idx), jobId);
        EthlanceDB(db).setUIntValue(sha3("contract/freelancer", idx), freelancerId);
        EthlanceDB(db).setUIntValue(sha3("contract/rate", idx), rate);
        EthlanceDB(db).setUInt8Value(sha3("contract/status", idx), 1);
        EthlanceDB(db).setUIntValue(sha3("contract/created-on", idx), now);
        JobActionLibrary.setStatus(db, jobActionId, 3);
        UserLibrary.addFreelancerContract(db, freelancerId, idx);
        JobLibrary.addJobContract(db, jobId, idx);
        if (isHiringDone) {
            JobLibrary.setHiringDone(db, jobId, senderId);
        }
    }

    function addTotalInvoiced(address db, uint contractId, uint amount) internal {
        EthlanceDB(db).addUIntValue(sha3("contract/total-invoiced", contractId), amount);
    }

    function subTotalInvoiced(address db, uint contractId, uint amount) internal {
        EthlanceDB(db).subUIntValue(sha3("contract/total-invoiced", contractId), amount);
    }

    function addInvoice(address db, uint contractId, uint invoiceId, uint amount) internal {
        SharedLibrary.addArrayItem(db, contractId, "contract/invoices", "contract/invoices-count", invoiceId);
        addTotalPaid(db, contractId, amount);
    }

    function getInvoices(address db, uint contractId) internal returns(uint[]) {
        return SharedLibrary.getUIntArray(db, contractId, "contract/invoices", "contract/invoices-count");
    }

    function getInvoices(address db, uint[] contractIds) internal returns(uint[] invoiceIds) {
        uint k = 0;
        for (uint i = 0; i < contractIds.length ; i++) {
            var contractInvoiceIds = getInvoices(db, contractIds[i]);
            for (uint j = 0; j < contractInvoiceIds.length ; j++) {
                invoiceIds[k] = contractInvoiceIds[j];
                k++;
            }
        }
    }

    function addTotalPaid(address db, uint contractId, uint amount) internal {
        EthlanceDB(db).addUIntValue(sha3("contract/total-paid", contractId), amount);
    }

    function getTotalPaid(address db, uint contractId) internal returns (uint) {
        return EthlanceDB(db).getUIntValue(sha3("contract/total-paid", contractId));
    }

    function getFreelancer(address db, uint contractId) internal returns (uint) {
        return EthlanceDB(db).getUIntValue(sha3("contract/freelancer", contractId));
    }

    function getEmployer(address db, uint contractId) internal returns (uint) {
        var jobId = EthlanceDB(db).getUIntValue(sha3("contract/job", contractId));
        return JobLibrary.getEmployer(db, jobId);
    }

    function getJob(address db, uint jobActionId) internal returns(uint) {
        return EthlanceDB(db).getUIntValue(sha3("contract/job", jobActionId));
    }

    function getStatus(address db, uint contractId) internal returns (uint8) {
        return EthlanceDB(db).getUInt8Value(sha3("contract/status", contractId));
    }

    function addFreelancerFeedback(address db, uint contractId, string description, uint8 rating) internal {
        var userId = getFreelancer(db, contractId);
        addUserFeedback(db, contractId, userId, "contract/freelancer-feedback",
            "contract/freelancer-feedback-rating", "contract/freelancer-feedback-on", "freelancer/ratings-count",
            "freelancer/avg-rating", description, rating);
    }
    
    function addEmployerFeedback(address db, uint contractId, string description, uint8 rating) internal {
        var userId = getEmployer(db, contractId);
        addUserFeedback(db, contractId, userId, "contract/employer-feedback",
            "contract/employer-feedback-rating", "contract/employer-feedback-on", "employer/ratings-count",
            "employer/avg-rating", description, rating);
    }

    function addUserFeedback(address db, uint contractId, uint userId, string feedbackKey,
        string ratingKey, string dateKey, string avgRatingKey, string ratingsCountKey, string description,
        uint8 rating) internal {
        EthlanceDB(db).setStringValue(sha3(feedbackKey, contractId), description);
        EthlanceDB(db).setUInt8Value(sha3(ratingKey, contractId), rating);
        EthlanceDB(db).setUIntValue(sha3(dateKey, contractId), now);
        UserLibrary.addToAvgRating(db, userId, ratingsCountKey, avgRatingKey, rating);
    }

    function addFeedback(address db, uint contractId, uint senderId, string feedback, uint8 rating) internal {
        var freelancerId = getFreelancer(db, contractId);
        var employerId = getEmployer(db, contractId);
        if (senderId != freelancerId && senderId != employerId) throw;

        if (getStatus(db, contractId) == 1) {
            EthlanceDB(db).setUInt8Value(sha3("contract/status", contractId), 2);
            EthlanceDB(db).setUIntValue(sha3("contract/done-on", contractId), now);
        }

        if (senderId == freelancerId) {
            EthlanceDB(db).setBooleanValue(sha3("contract/done-by-freelancer?", contractId), true);
            addFreelancerFeedback(db, contractId, feedback, rating);
        } else {
            addEmployerFeedback(db, contractId, feedback, rating);
        }
    }
}